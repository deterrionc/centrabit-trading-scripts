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
float   SELLPERCENT     = 80.0;                   # Overbought threshold possible sell signal
float   BUYPERCENT      = 20.0;                   # Oversold threshold possible buy signal
integer STOCLENGTH      = 14;                     # Stochastic Oscillator K length, Best Length is [14]
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

void onOwnOrderFilledTest(transaction t) {
  setCurrentChartPosition("0");
  float amount = t.price * t.amount;
  feeTotal += t.fee;

  if (t.isAsk == false) {                   # when sell order fillend
    sellTotal += amount;
  } else {                                  # when buy order filled
    buyTotal += amount;
  }

  integer isOddOrder = t.marker % 2;
  integer tradeNumber = (t.marker - 1) / 2 + 1;
  string tradeLog = "   ";

  if (isOddOrder == 0) {
    printFillLogs(t, toString(sellTotal - buyTotal - feeTotal));

    string tradeNumStr = toString(tradeNumber);
    for (integer i = 0; i < strlength(tradeNumStr); i++) {
      tradeLog += " ";
    }
    float profit;
    if (t.isAsk == false) {
      tradeSign = "LX";
      profit = amount - entryAmount - t.fee - entryFee;
      tradeLog += "\tLX\t";
    } else {
      tradeSign = "SX";
      profit = entryAmount - amount - t.fee - entryFee;
      tradeLog += "\tSX\t";
    }

    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0);
    tradeLogList >> tradeLog;

    if (tradeSign == "LX") {
      tradeLog = "\tSE\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);
      tradeLogList >> tradeLog;
    }

    if (tradeSign == "SX") {
      tradeLog = "\tLE\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);
      tradeLogList >> tradeLog;
    }

    if (profit >= 0.0) {
      totalWin += profit;
      winCount++;
      if (profitSeriesColor == "red") {
        profitSeriesColor = "green";
      }
    } else {
      totalLoss += fabs(profit);
      lossCount++;
      if (profitSeriesColor == "green") {
        profitSeriesColor = "red";
      }
    }

    profitSeriesID++;
    setCurrentSeriesName("Direction" + toString(profitSeriesID));
    configureLine(false, profitSeriesColor, 2.0);
    drawChartPoint(entryTran.tradeTime, entryTran.price);
    drawChartPoint(currentTran.tradeTime, currentTran.price);
    entryTran = currentTran;
  } else {
    printFillLogs(t, "");

    if (tradeSign == "LX") {
      tradeLog = "\tSX\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0);
      tradeLogList >> tradeLog;
    }
    if (tradeSign == "SX") {
      tradeLog = "\tLX\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0);
      tradeLogList >> tradeLog;
    }

    tradeLog = "   ";  
    tradeLog += toString(tradeNumber);
    if (t.isAsk == false) {
      tradeSign = "SE";
      tradeLog += "\tSE\t";
    } else {
      tradeSign = "LE";
      tradeLog += "\tLE\t";
    }
    entryAmount = amount;
    entryFee = t.fee;

    if (tradeSign == "SE") {
      if (currentTran.price > entryTran.price) {
        profitSeriesColor = "green";
      } else {
        profitSeriesColor = "red";
      }
    }

    if (tradeSign == "LE") {
      if (currentTran.price > entryTran.price) {
        profitSeriesColor = "red";
      } else {
        profitSeriesColor = "green";
      }
    }

    if (tradeNumber == 1) {
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(AMOUNT / 2.0);
      tradeLogList >> tradeLog;
    } else {
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(AMOUNT / 2.0);
      tradeLogList >> tradeLog;
    }

    if (tradeNumber > 1) {
      profitSeriesID++;
      setCurrentSeriesName("Direction" + toString(profitSeriesID));
      configureLine(false, profitSeriesColor, 2.0);
      drawChartPoint(entryTran.tradeTime, entryTran.price);
      drawChartPoint(currentTran.tradeTime, currentTran.price);
    }
    
    entryTran = currentTran;
  }
}

void onPubOrderFilledTest(transaction t) {
  currentTran = t;
  updateStocParams(t);

  setCurrentChartPosition("1");
  drawChartPointToSeries("Stoc", t.tradeTime, stocValue);
  drawChartPointToSeries("P1", t.tradeTime, SELLPERCENT);
  drawChartPointToSeries("P2", t.tradeTime, BUYPERCENT);
  setCurrentChartPosition("0");

  if (stocValue >= SELLPERCENT) {
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
      drawChartPointToSeries("Sell", t.tradeTime, t.price);
    }
  }

  if (stocValue <= BUYPERCENT) {
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
      drawChartPointToSeries("Buy", t.tradeTime, t.price);
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

  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();
  setChartBarCount(10);
  setChartBarWidth(24 * 60 * 60 * 1000000);                                # 1 day 
  setChartTime(transForTest[0].tradeTime +  9 * 24 * 60 * 60 * 1000000);      # 9 days
  setChartDataTitle("Stochastic - " + toString(STOCLENGTH));
  setCurrentSeriesName("Sell");
  configureScatter(true, "red", "red", 7.0);
  setCurrentSeriesName("Buy");
  configureScatter(true, "#7dfd63", "#187206", 7.0,);
  setCurrentSeriesName("Direction");
  configureLine(true, "green", 2.0);
  setChartsPairBuffering(true);

  setCurrentChartPosition("1");
  setChartDataTitle("Stochastic - " + toString(STOCLENGTH));
  setChartYRange(0.0, 100.0); 
  setCurrentSeriesName("Stoc");
  configureLine(true, "blue", 1.0);
  setCurrentSeriesName("P1");
  configureLine(true, "pink", 1.0);
  setCurrentSeriesName("P2");
  configureLine(true, "pink", 1.0);

  integer sleepFlag = 0;

  currentOrderId = 0;
  for (integer i = STOCLENGTH; i < sizeof(transForTest); i++) {
    if (i % 100 == 0) {
      onPubOrderFilledTest(transForTest[i]);
    }
    
    sleepFlag = i % 1000;
    if (sleepFlag == 0) {
      msleep(20);
    }
  }

  setChartsPairBuffering(false);

  integer totalCount = winCount + lossCount;
  float rewardToRiskRatio = totalWin / totalLoss;
  float winLossRatio = toFloat(winCount) / toFloat(lossCount);
  float winRatio = toFloat(winCount) / toFloat(totalCount);
  float lossRatio = toFloat(lossCount) / toFloat(totalCount);
  float averageWin = totalWin / toFloat(winCount);
  float averageLoss = totalLoss / toFloat(lossCount);
  float tharpExpectancy = ((winRatio * averageWin) - (lossRatio * averageLoss) ) / (averageLoss);

  string resultString;
  if (tharpExpectancy >= EXPECTANCYBASE) {
    resultString = "PASS";
  } else {
    resultString = "FAIL";
  }

  string tradeListTitle = "\tTrade\tTime\t\t" + SYMBOLSETTING + "\t\t" + getBaseCurrencyName(SYMBOLSETTING) + "(per)\tProf" + getQuoteCurrencyName(SYMBOLSETTING) + "\t\tAcc";

  print("\n\n-----------------------------------------------------------------------------------------------------------------------");
  print(tradeListTitle);
  print("-----------------------------------------------------------------------------------------------------------------------");
  for (integer i = 0; i < sizeof(tradeLogList); i++) {
    print(tradeLogList[i]);
  }
  print("-----------------------------------------------------------------------------------------------------------------------\n");

  print("Reward-to-Risk Ratio : " + toString(rewardToRiskRatio));
  print("Win/Loss Ratio : " + toString(winLossRatio));
  print("Win Ratio  : " + toString(winRatio));
  print("Loss Ratio : " + toString(lossRatio));
  print("Expectancy : " + toString(tharpExpectancy));
  print("@ Expectancy Base: " + toString(EXPECTANCYBASE));
  print(" ");
  print("Result : " + resultString);
  print("Total profit : " + toString(sellTotal - buyTotal - feeTotal));
  print("*****************************");

  return sellTotal - buyTotal;
}

backtest();