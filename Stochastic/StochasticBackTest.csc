# Stochastic Oscillator trading strategy backtest 1.0.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script StochasticBackTest;

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
integer STOCLENGTH      = 14;                     # ATR period length (Best Length is 14)
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

# Trading Variables
string  position        = "flat";
string  prevPosition    = "";
integer resolution      = interpretResol(RESOL);
integer currentOrderId  = 0;
integer buyCount        = 0;
integer sellCount       = 0;
integer winCount        = 0;
integer lossCount       = 0;
float   buyTotal        = 0.0;
float   sellTotal       = 0.0;
float   totalWin        = 0.0;
float   totalLoss       = 0.0;
float   feeTotal        = 0.0;
float   entryAmount     = 0.0;
float   entryFee        = 0.0;
string  tradeLogList[];

# Additional needs in backtest mode
string  profitSeriesColor       = "green";
string  tradeSign               = "";
integer profitSeriesID          = 0;
transaction currentTran;
transaction entryTran;

void updateStocParams(transaction t) {
  delete stocPrices[0];
  stocPrices >> t.price;
  stocValue = getStocValue(stocPrices);
}