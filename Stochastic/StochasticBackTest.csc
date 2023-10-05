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
string  profitSeriesColor  = "green";
string  tradeSign          = "";
integer profitSeriesID     = 0;
transaction currentTran;
transaction entryTran;

void updateStocParams(transaction t) {
  delete stocPrices[0];
  stocPrices >> t.price;
  stocValue = getStocValue(stocPrices);
}

void onPubOrderFilledTest(transaction t) {
  updateStocParams(t);

  if (stocValue >= 80.0) {
    boolean sellSignal = false;

    if (position == "long") {
      sellSignal = true;
    } else if (position == "flat") {
      if (prevPosition == "") {
        sellSignal = true;
      }
      if (prevPosition == "short") {
        sellSignal = true;
      }
    }

    if (sellSignal) {
      currentOrderId++;
      if (currentOrderId == 1) {
        printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT / 2.0, "");
      } else {
        printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "");
      }

      # Emulate Sell Order
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price;
      if (currentOrderId == 1) {
        filledTran.amount = AMOUNT / 2.0;
        filledTran.fee = AMOUNT / 2.0 * t.price * FEE;
      } else {
        filledTran.amount = AMOUNT;
        filledTran.fee = AMOUNT * t.price * FEE;
      }
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = false;
      onOwnOrderFilledTest(filledTran);
      if (position == "flat") {
        if (prevPosition == "") {
          prevPosition = "short";
        }
        position = "short";
        prevPosition = "flat";
      } else {
        position = "flat";
        prevPosition = "long";
      }
      sellCount++;
      # drawChartPointToSeries("Sell", t.tradeTime, t.price);
    }
  }

  if (stocValue <= 20.0) {
    boolean buySignal = false;
    if (position == "short") {
      buySignal = true;
    } else if (position == "flat") {
      if (prevPosition == "") {
        buySignal = true;
      }
      if (prevPosition == "long") {
        buySignal = true;
      }
    }

    if (buySignal) {
      currentOrderId++;
      if (currentOrderId == 1) {
        printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT / 2.0, "");
      } else {
        printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "");
      }
  
      # emulating buy order filling
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price;
      if (currentOrderId == 1) {
        filledTran.amount = AMOUNT / 2.0;
        filledTran.fee = AMOUNT / 2.0 * t.price * FEE;
      } else {
        filledTran.amount = AMOUNT;
        filledTran.fee = AMOUNT * t.price * FEE;
      }
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = true;
      onOwnOrderFilledTest(filledTran);

      if (position == "flat") {
        if (prevPosition == "") {
          prevPosition = "long";
        }
        position = "long";
        prevPosition = "flat";
      } else {
        position = "flat";
        prevPosition = "short";
      }

      buyCount++;
      # drawChartPointToSeries("Buy", t.tradeTime, t.price);
    }
  }
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

  integer sleepFlag = 0;

  currentOrderId = 0;
  for (integer i = STOCLENGTH; i < sizeof(transForTest); i++) {
    onPubOrderFilledTest(transForTest[i]);
    
    #sleepFlag = i % 1000;
    #if (sleepFlag == 0) {
      msleep(2);
    #}
  }

  return sellTotal - buyTotal;
}

backtest();