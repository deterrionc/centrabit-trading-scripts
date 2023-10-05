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

void onPubOrderFilledTest(transaction t) {
  if (stocValue >= 80.0) {
    print("SELL");
  }

  if (stocValue <= 20.0) {
    print("BUY");
  }

  updateStocParams(t);
}

float backtest() {
  print("^^^^^^^^ Stochastic Oscillator Backtest ( EXCHANGE : " + EXCHANGESETTING + ", CURRENCY PAIR : " + SYMBOLSETTING + ") ^^^^^^^^^\n");
  integer testStartTime = stringToTime(STARTDATETIME, "yyyy-MM-dd hh:mm:ss");
  integer testEndTime;
  integer currentTime = getCurrentTime();

  if (ENDDATETIME == "now") {
    testEndTime = currentTime;
  } else {
    testEndTime = stringToTime(ENDDATETIME, "yyyy-MM-dd hh:mm:ss");
  }

  # Checking Maximum Back Test Period
  integer testTimeLength = testEndTime - testStartTime;
  if (testTimeLength > 31536000000000) { # maximum backtest available length is 1 year = 365  * 24 * 60 * 60 * 1000000 ns
    print("You exceeded the maximum backtest period.\nPlease try again with another STARTDATETIME setting");
    return;
  }

  print("Fetching transactions from " + STARTDATETIME + " to " + ENDDATETIME + "...");
  transaction transForTest[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, testStartTime, testEndTime);

  for (integer i = 0; i < STOCLENGTH; i++) {
    stocPrices >> transForTest[i].price;
  }

  stocValue = getStocValue(stocPrices);

  print("Initial Stochastic Oscillator K :" + toString(stocValue));
  print("--------------   Running   -------------------");

  currentOrderId = 0;
  for (integer i = STOCLENGTH; i < sizeof(transForTest); i++) {
    onPubOrderFilledTest(transForTest[i]);
  }
}