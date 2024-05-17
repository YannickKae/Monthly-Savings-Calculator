# Load necessary libraries
library(shiny)
library(shinythemes)
library(shinyMatrix)
library(ggplot2)
library(quantmod)
library(mice)
library(plotly)

# Define the user interface
ui <- fluidPage(
  theme = shinytheme("darkly"),
  titlePanel("Monthly Savings Calculator"),
  
  sidebarLayout(
    sidebarPanel(
      numericInput("initial_amount", "Initial Amount", value = 10000, min = 0, step = 1000),
      numericInput("final_amount", "Desired Final Amount", value = 100000, min = 0, step = 10000),
      numericInput("years", "Years", value = 5, min = 1, step = 1),
      numericInput("probability", "Probability of Success", value = 0.8, min = 0, max = 1, step = 0.05),
      
      selectInput("emprical_distribution", "Distribution from which to sample monthly Returns", 
                  choices = c("Normal Distribution" = "ND", "Portfolio Distribution" = "PD", "Empirical Distribution" = "ED")),
      
      conditionalPanel(
        condition = "input.emprical_distribution == 'ED'",
        fileInput("file", "Choose CSV File", multiple = FALSE, accept = c("text/csv", "text/comma-separated-values,text/plain", ".csv")),
        checkboxInput("header", "Header", TRUE),
        radioButtons("sep", "Separator", choices = c(Comma = ",", Semicolon = ";", Tab = "\t"), selected = ",")
      ),
      
      conditionalPanel(
        condition = "input.emprical_distribution == 'ND'",
        numericInput("mean", "Arithmetic mean monthly Return", value = 0.0071, min = 0, step = 0.0001),
        numericInput("volatility", "Monthly Volatility", value = 0.0558, min = 0, step = 0.0001)
      ),
      
      conditionalPanel(
        condition = "input.emprical_distribution == 'PD'",
        matrixInput("input_matrix", "Portfolio",
                    value = matrix(data = c("SPYI.F", "BTC-EUR", 0.95, 0.05), nrow = 2, ncol = 2, dimnames = list(NULL, c("Ticker", "Weight"))),
                    rows = list(extend = TRUE, names = FALSE),
                    cols = list(names = TRUE)),
        checkboxInput("imputation", "Align periods by Imputation?", FALSE)
      ),
      
      numericInput("simulations", "Simulations", value = 10000, min = 1),
      numericInput("seed", "Seed", value = 12345),
      actionButton("submit", "Calculate")
    ),
    
    mainPanel(
      fluidRow(wellPanel(plotOutput("histogram"))),
      fluidRow(wellPanel(plotOutput("cdf"))),
      fluidRow(wellPanel(textOutput("text")))
    )
  )
)

# Define the server logic
server <- function(input, output) {
  observeEvent(input$submit, {
    set.seed(input$seed)
    
    months <- input$years * 12
    gross_returns <- matrix(nrow = months, ncol = input$simulations)
    amount <- matrix(nrow = months + 1, ncol = input$simulations)
    amount[1, ] <- input$initial_amount
    
    if (input$emprical_distribution == "ED") {
      inFile <- input$file
      if (is.null(inFile)) stop("Please upload a file.")
      
      data <- read.csv(inFile$datapath, header = input$header, sep = input$sep)
      names(data)[1] <- "Header"
      gross_returns <- replicate(input$simulations, sample(1 + data$Header, size = months, replace = TRUE))
      
    } else if (input$emprical_distribution == "ND") {
      gross_returns <- replicate(input$simulations, 1 + rnorm(months, mean = input$mean, sd = input$volatility))
      
    } else {
      m <- input$input_matrix[!apply(input$input_matrix == "", 1, all), ]
      if (is.null(dim(m))) m <- t(as.matrix(m))
      
      getSymbols(m[, 1], src = "yahoo", from = "1900-01-01")
      assets <- lapply(1:length(m[, 1]), function(i) monthlyReturn(get(m[i, 1])[, 6], leading = FALSE))
      return_matrix <- do.call("merge.xts", assets)
      
      if (input$imputation) {
        imputed_data <- mice(return_matrix, m = max(round(sum(!complete.cases(return_matrix)) / nrow(return_matrix) * 100), 1), maxit = length(m[, 1]))
        return_matrix <- complete(imputed_data)
      } else {
        return_matrix <- na.omit(return_matrix)
      }
      
      gross_returns <- replicate(input$simulations, sample(1 + as.matrix(return_matrix) %*% as.numeric(m[, 2]), size = months, replace = TRUE))
    }
    
    min_savings <- 0
    max_savings <- input$final_amount %/% input$years
    
    while (min_savings < max_savings) {
      savings <- (min_savings + max_savings) %/% 2
      for (x in 1:months) {
        amount[x + 1, ] <- (savings + amount[x, ]) * gross_returns[x, ]
      }
      if (sum(amount[months + 1, ] > input$final_amount) / input$simulations >= input$probability) {
        max_savings <- savings
      } else {
        min_savings <- savings + 1
      }
    }
    
    output$histogram <- renderPlot({
      ggplot(data = data.frame(amount = amount[months + 1, ]), aes(x = amount)) +
        geom_histogram(aes(y = after_stat(density)), bins = min(100, input$simulations), color = "black", fill = "black", alpha = 1) +
        geom_density(color = "red", alpha = 1, linewidth = 1) +
        geom_vline(xintercept = input$final_amount, color = "darkred", linewidth = 2) +
        ggtitle("Scenario Distribution") +
        labs(y = "Density", x = "Final Amount") +
        theme(text = element_text(size = 18, color = "black"), axis.text = element_text(size = 15, color = "black"), plot.title = element_text(hjust = 0.5))
    })
    
    output$cdf <- renderPlot({
      data <- data.frame(amount = amount[months + 1, ])
      ggplot(data, aes(x = amount)) +
        stat_ecdf(geom = "step", color = "black", linewidth = 2) +
        geom_vline(xintercept = input$final_amount, color = "darkred", linewidth = 2) +
        geom_hline(yintercept = 1 - input$probability, color = "darkred", linewidth = 2) +
        ggtitle("Scenario CDF") +
        labs(x = "Final Amount", y = "Probability") +
        theme(text = element_text(size = 18, color = "black"), axis.text = element_text(size = 15, color = "black"), plot.title = element_text(hjust = 0.5))
    })
    
    output$text <- renderText({
      if (input$initial_amount + months * min_savings >= input$final_amount) {
        paste("You would have to invest at least", min_savings, "each month in your risky securities portfolio, but it would be both safer and more capital efficient to simply save", max(round((input$final_amount - input$initial_amount) / months, 0), 1), "each month without risk.")
      } else {
        paste("You have to invest at least", min_savings, "each month in your risky securities portfolio. If you did not invest, but simply saved without risk, you would have to save", as.integer((input$final_amount - input$initial_amount) / months), "each month. Accordingly, investing would be more capital efficient considering the given probability.")
      }
    })
  })
}

shinyApp(ui = ui, server = server)
