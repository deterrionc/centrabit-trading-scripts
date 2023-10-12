# Stochastic Oscillator trading strategy Optimization Test 1.0.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script StochasticOptimizationTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;
import Processes;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
float   SELLPERCENT     = 80.0;                   # Overbought threshold possible sell signal
float   BUYPERCENT      = 20.0;                   # Oversold threshold possible buy signal
integer STOCLENGTHSTART = 14;                     # Stochastic Oscillator K length, Best Length is [14]
integer STOCLENGTHEND   = 14;                     # Stochastic Oscillator K length, Best Length is [14]
integer STOCLENGTHSTEP  = 1;                      # Stochastic Oscillator K length, Best Length is [14]
string  RESOL           = "30m";                  # Bar resolution
float   AMOUNT          = 1.0;                    # The amount of buy or sell order at once
string  STARTDATETIME   = "2023-07-01 00:00:00";  # Backtest start datetime
string  ENDDATETIME     = "now";                  # Backtest end datetime
float   EXPECTANCYBASE  = 0.1;                    # expectancy base
float   FEE             = 0.002;                  # trading fee as a decimal (0.2%)
#############################################

# Stochastic Variables
float stocValue = 0.0;
float stocPrices[];
transaction transactions[];