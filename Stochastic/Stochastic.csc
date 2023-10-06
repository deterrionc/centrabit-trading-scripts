# Stochastic trading strategy 1.0.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script Stochastic;

# System Libraries
import IO;
import Math;
import Strings;
import Trades;
import Time;
import Charts;
import Files;
import Processes;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
float   SELLPERCENT     = 80.0;                             # Overbought threshold possible sell signal
float   BUYPERCENT      = 20.0;                             # Oversold threshold possible buy signal
integer STOCLENGTH      = 14;                               # Stochastic Oscillator K length, Best Length is [14]
string  RESOL           = "1m";                             # Bar resolution
float   AMOUNT          = 1.0;                              # The amount of buy or sell order at once
string  logFilePath     = "c:/stochastic_log_tradelist_";   # Please make sure this path any drive except C:
#############################################

# Stochastic Variables
float stocValue = 0.0;
float stocPrices[];
transaction transactions[];

# Trading Variables
