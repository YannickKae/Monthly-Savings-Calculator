# Monthly Savings Calculator

The [Monthly Savings Calculator](https://yannickkaelber.shinyapps.io/MonthlySavings/) is an interactive web application developed with R Shiny. It allows users to calculate the monthly investment required to reach a desired end amount. The calculations are based on different possible return distributions and risk profiles.

## Features

The application provides a number of user-definable input parameters:

- **Initial Amount**: This is the amount the user has at the beginning of the savings period.
- **Desired End Amount**: This is the amount the user would like to have at the end of the savings period.
- **Years**: The number of years the user wishes to save.
- **Probability of Success**: The probability that the user will reach the desired final amount.
- **Return Distribution**: The user has the option to select the distribution of the monthly returns. There are three options to choose from: Normal Distribution, Portfolio Distribution and Empirical Distribution.

Depending on the selected return distribution, additional input fields are displayed. For example, if Empirical is selected, users can upload a CSV file of monthly returns.

The application performs a series of calculations and provides three main outputs:

- **Scenario Distribution**: A histogram showing the distribution of final amounts across all scenarios.
- **Scenario CDF**: A cumulative distribution function (CDF) showing the probability of meeting or exceeding a given ending amount.
- **Monthly Investment Required**: The monthly investment required to reach the desired ending amount with the specified probability.

## Background Computations

A Monte Carlo simulation is used to generate many possible scenarios for monthly returns to obtain a distribution of final amounts.
The returns can either be normally distributed, come from a portfolio distribution, or have an empirical distribution based on user-uploaded data.
After the simulation is run, the application uses the bisection method to find the minimum monthly savings amount needed to reach the desired final amount with the specified probability.
In this case, the interval between the minimum and maximum monthly savings amounts (defined as the desired final amount divided by the number of months) is divided until the minimum required monthly savings amount is found. This amount is the one that satisfies the condition that the final amounts equal or exceed the desired final amount with at least the desired probability.

## How to use

To use the application, simply enter your parameters in the form on the left and click "Calculate". The results are displayed in the right column.
