# PSAR (Parabolic Stop And Reverse) trading strategy optimization test - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script PSAROptimizationTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;
import Math;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
float   AFINITSTART     = 0.02;
float   AFINITEND       = 0.02;
float   AFINITSTEP      = 0.01;
float   AFMAXSTART      = 0.2;
float   AFMAXEND        = 0.2;
float   AFMAXSTEP       = 0.02;
float   AFSTEPSTART     = 0.02;
float   AFSTEPEND       = 0.02;
float   AFSTEPSTEP      = 0.001;
string  RESOLSTART      = "6h";
string  RESOLEND        = "12h";
string  RESOLSTEP       = "6h";
float   AMOUNT          = 1.0;                      # The amount of buy or sell order at once
string  STARTDATETIME   = "2023-07-01 00:00:00";    # Backtest start datetime
string  ENDDATETIME     = "now";                    # Backtest end datetime
float   EXPECTANCYBASE  = 0.1;                      # expectancy base
float   FEE             = 0.002;                    # trading fee as a decimal (0.2%)
#############################################

# PSAR Variables
float   highs[];
float   lows[];
float   psar;
string  trend;     # "", "up", "down"
float   ep = 0.0;
float   af;
float   AFINIT;
float   AFMAX;
float   AFSTEP;

# Trading Variables
string  RESOL;
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
float   minFillOrderPercentage = 0.0;
float   maxFillOrderPercentage = 0.0;
boolean reversed;
bar barData[];
integer resolution;
integer barSize;

# Own order filled handler
void onOwnOrderFilledTest(transaction t) {
  float amount = t.price * t.amount;
  feeTotal += t.fee;

  if (t.isAsk == false) {                   # when sell order fillend
    sellTotal += amount;
  } else {                                  # when buy order fillend
    buyTotal += amount;
  }

  integer isOddOrder = t.marker % 2;
  integer tradeNumber = (t.marker-1) / 2 + 1;
  string tradeLog = "   ";

  if (isOddOrder == 0) {
    print(toString(t.marker) + " filled (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + toString(t.price) + " * " + toString(t.amount) + ",  fee: " + toString(t.fee) + ",  Total profit: " + toString(sellTotal - buyTotal - feeTotal));
    string tradeNumStr = toString(tradeNumber);
    for (integer i = 0; i < strlength(tradeNumStr); i++) {
      tradeLog =  tradeLog + " ";
    }
    float profit;
    if (t.isAsk == false) {
      profit = amount - entryAmount - t.fee - entryFee;
      tradeLog += "\tLX\t";
    } else {
      profit = entryAmount - amount - t.fee - entryFee;
      tradeLog += "\tSX\t";
    }

    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);

    if (profit >= 0.0 ) {
      totalWin += profit;
      winCount ++;
    } else {
      totalLoss += fabs(profit);
      lossCount ++;
    }
    tradeLogList >> tradeLog;
  } else {
    print(toString(t.marker) + " filled (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + toString(t.price) + " * " + toString(t.amount) + ",  fee: " + toString(t.fee));

    tradeLog += toString(tradeNumber);
    if (t.isAsk == false) {
      tradeLog += "\tSE\t";
    } else {
      tradeLog += "\tLE\t";
    }
    entryAmount = amount;
    entryFee = t.fee;
    tradeLog = tradeLog +  timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t" + toString(AMOUNT) + "\t\t\t" + toString(AMOUNT);
    tradeLogList >> tradeLog;
  }
}

void onTimeOutTest(integer i) {
  float highest;
  float lowest;

  string oldTrend = trend;

  if (trend == "up") {  # while upward trending 
    # Calculate the new PSAR
    psar = psar + af * ( ep - psar);
    # Ensure the latest PSAR value is as low or lower than the low price of the past two days
    lowest = fmin(lows[0], lows[1]);
    psar = fmin(psar, lowest);

    # Add the latest prices to the current trend list
    delete highs[0];
    delete lows[0];
    highs >> barData[i].highPrice;
    lows >> barData[i].lowPrice;

    # check for a trend reversal
    if (psar <= lows[1]) {
      trend = "up";
      reversed = false;
    } else {
      psar = fmax(highs[0], highs[1]);
      trend = "down";
      reversed = true;
    }

    # Update the extreme point and af
    if (reversed == true) {
      ep = lows[1];
      af = AFINIT;
    } else if (highs[1] > ep) {
      ep = highs[1];
      af = fmin(af+AFSTEP, AFMAX);
    }
  } else { # while downward trending
    # Calculate the new PSAR
    psar = psar - af * ( psar - ep);
    # Ensure the latest PSAR value is as low or lower than the low price of the past two days
    highest = fmax(highs[0], highs[1]);
    psar = fmax(psar, highest);

    # Add the latest prices to the current trend list
    delete highs[0];
    delete lows[0];
    highs >> barData[i].highPrice;
    lows >> barData[i].lowPrice;

    # check for a trend reversal
    if (psar >= highs[1]) {
      trend = "down";
      reversed = false;
    } else {
      psar = fmin(lows[0], lows[1]);
      trend = "up";
      reversed = true;
    }

    # Update the extreme point and af
    if (reversed == true) {
      ep = highs[1];
      af = AFINIT;
    } else if (lows[1] < ep) {
      ep = lows[1];
      af = fmin(af+AFSTEP, AFMAX);
    }
  }

  print("DateTime: " + timeToString(barData[i].timestamp, "yyyy-MM-dd hh:mm:ss") + ", High: " + toString(highs[1]) + ", Low: " + toString(lows[1]) + ", PSAR: " + toString(psar) + ", EP: " + toString(ep) + ", AF: " + toString(af) + ", Trend: " + trend);

  transaction barTransactions[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, barData[i].timestamp, barData[i].timestamp+barSize);
  transaction lastTransaction = barTransactions[0];
  transaction t;

  if (trend == "up") {
    drawChartPointToSeries("Upword", barData[i].timestamp, psar);
    if (oldTrend != "up") {
      currentOrderId++;
      print(toString(currentOrderId) + " buy order (" + timeToString(lastTransaction.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(lastTransaction.price) + "  amount: "+ toString(AMOUNT));
      t.id = currentOrderId;
      t.marker = currentOrderId;
      t.price = lastTransaction.price + lastTransaction.price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
      t.amount = AMOUNT;
      t.fee = AMOUNT*t.price*FEE * 0.01;
      t.tradeTime = lastTransaction.tradeTime;
      t.isAsk = true;
      onOwnOrderFilledTest(t);
      buyCount ++;
      drawChartPointToSeries("Buy", lastTransaction.tradeTime, lastTransaction.price);      
      drawChartPointToSeries("Direction", lastTransaction.tradeTime, lastTransaction.price); 
    }
  } else {
    drawChartPointToSeries("Downward", barData[i].timestamp, psar);
    if (oldTrend != "down") {
      currentOrderId++;
      print(toString(currentOrderId) + " sell order (" + timeToString(lastTransaction.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(lastTransaction.price) + "  amount: "+ toString(AMOUNT));
      t.id = currentOrderId;
      t.marker = currentOrderId;
      t.price = lastTransaction.price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
      t.amount = AMOUNT;
      t.fee = AMOUNT*t.price*FEE * 0.01;
      t.tradeTime = lastTransaction.tradeTime;
      t.isAsk = false;
      onOwnOrderFilledTest(t);
      sellCount ++;
      drawChartPointToSeries("Sell", lastTransaction.tradeTime, lastTransaction.price);
      drawChartPointToSeries("Direction", lastTransaction.tradeTime, lastTransaction.price); 
    }
  }
}

float backtest() {
  currentOrderId = 0;
  buyTotal = 0.0;
  buyCount = 0;
  sellTotal = 0.0;
  sellCount = 0;
  feeTotal = 0.0;
  totalWin = 0.0;
  winCount = 0;
  totalLoss = 0.0;
  lossCount = 0;
  entryAmount = 0.0;
  entryFee = 0.0;
  delete tradeLogList;

  resolution = interpretResol(RESOL);
  barSize = resolution * 60 * 1000 * 1000;

  # Fetching the historical trading data of given datatime period
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
  if (testTimeLength >  15724800000000) { # maximum backtest available length is 6 months = 365 / 2 * 24 * 60 * 60 * 1000000 ns 
    print("You exceeded the maximum backtest period.\nPlease try again with another STARTDATETIME setting");
    return;
  }

  integer barCnt = testTimeLength / barSize + 3;
  barData = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, testEndTime, barCnt, barSize);
  if (sizeof(barData) == 0) {
    print("Lookback bar data fetching failed! " + toString(sizeof(barData)) + " fetched.");
    return;
  }

  if (barData[1].highPrice >= barData[0].highPrice) {
    trend = "up";       # the trend of the day before
  } else {
    trend = "down";
  }

  # PSAR initialization
  highs >> barData[1].highPrice;
  highs >> barData[2].highPrice;
  lows >> barData[1].lowPrice;
  lows >> barData[2].lowPrice;

  reversed = false;
  af = AFINIT;

  if (trend == "up") {
    psar = fmin(lows[0], lows[1]);
    ep = fmax(highs[0], highs[1]);
    if (highs[1] > psar) {
      trend = "up";
      reversed = false;
    } else {
      trend = "down";
      reversed = true;
    }
  } else {
    trend = "down";  
    psar = fmax(highs[0], highs[1]);
    ep = fmin(lows[0], lows[1]);
    if (lows[1] < psar) {
      trend = "down";
      reversed = false;
    } else {
      trend = "up";
      reversed = true;
    }
  }

  print("DateTime: " + timeToString(barData[2].timestamp, "yyyy-MM-dd hh:mm:ss") + ", High: " + toString(highs[1]) + ", Low: " + toString(lows[1]) + ", PSAR: " + toString(psar) + ", EP: " + toString(ep) + ", AF: " + toString(af) + ", Trend: " + trend);

  float minAskOrderPrice = getOrderBookAsk(EXCHANGESETTING, SYMBOLSETTING);
  float maxBidOrderPrice = getOrderBookBid(EXCHANGESETTING, SYMBOLSETTING);

  order askOrders[] = getOrderBookByRangeAsks(EXCHANGESETTING, SYMBOLSETTING, 0.0, 1.0);
  order bidOrders[] = getOrderBookByRangeBids(EXCHANGESETTING, SYMBOLSETTING, 0.0, 1.0);


  minFillOrderPercentage = bidOrders[0].price/askOrders[sizeof(askOrders)-1].price;
  maxFillOrderPercentage = bidOrders[sizeof(bidOrders)-1].price/askOrders[0].price;
  if (AMOUNT < 10.0) {
    minFillOrderPercentage = maxFillOrderPercentage * 0.999;
  } else if (AMOUNT <100.0) {
    minFillOrderPercentage = maxFillOrderPercentage * 0.998;
  } else if (AMOUNT < 1000.0) {
    minFillOrderPercentage = maxFillOrderPercentage * 0.997;
  } else {
    minFillOrderPercentage = maxFillOrderPercentage * 0.997;
  }

  currentOrderId = 0;

  if (trend == "up") {
    drawChartPointToSeries("Upword", barData[2].timestamp, psar);
  } else {
    drawChartPointToSeries("Downward", barData[2].timestamp, psar);
  }

  integer msleepFlag = 0;
  integer shouldBePositionClosed;

  setChartsPairBuffering(true);

  for (integer i = 3; i < sizeof(barData); i++) {
    onTimeOutTest(i);
    if (i == sizeof(barData)-1) {
      shouldBePositionClosed = currentOrderId % 2;
      if ((shouldBePositionClosed == 1)) {
        transaction barTransactions[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, barData[i].timestamp, barData[i].timestamp+barSize);
        transaction lastTransaction = barTransactions[0];
        transaction t;

        if (trend == "down") {
          currentOrderId++;
          print(toString(currentOrderId) + " buy order (" + timeToString(lastTransaction.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(lastTransaction.price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = lastTransaction.price + lastTransaction.price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = lastTransaction.tradeTime;
          t.isAsk = true;
          onOwnOrderFilledTest(t);
          buyCount ++;
          drawChartPointToSeries("Buy", lastTransaction.tradeTime, lastTransaction.price);      
          drawChartPointToSeries("Direction", lastTransaction.tradeTime, lastTransaction.price); 
        } 
        else {
          currentOrderId++;
          print(toString(currentOrderId) + " sell order (" + timeToString(lastTransaction.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(lastTransaction.price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = lastTransaction.price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = lastTransaction.tradeTime;
          t.isAsk = false;
          onOwnOrderFilledTest(t);
          sellCount ++;
          drawChartPointToSeries("Sell", lastTransaction.tradeTime, lastTransaction.price);
          drawChartPointToSeries("Direction", lastTransaction.tradeTime, lastTransaction.price); 
        }
      }
    }

    msleepFlag = i % 2000;
    if ( msleepFlag == 0) {
      msleep(20);
    }  
  }

  setChartsPairBuffering(false);


  float rewardToRiskRatio = totalWin / totalLoss;
  float winLossRatio = toFloat(winCount) / toFloat(lossCount);
  float winRatio = toFloat(winCount) / toFloat(winCount+lossCount);
  float lossRatio = toFloat(lossCount) / toFloat(winCount+lossCount);
  float expectancyRatio = rewardToRiskRatio * winRatio - lossRatio;

  float averageWin = totalWin / toFloat(winCount);
  float averageLoss = totalLoss / toFloat(lossCount);
  integer totalCount = winCount + lossCount;
  float winPercentage = toFloat(winCount) / toFloat(totalCount);
  float lossPercentage = toFloat(lossCount) / toFloat(totalCount);

  float tharpExpectancy = ((winPercentage * averageWin) - (lossPercentage * averageLoss) ) / (averageLoss);

  string resultString;
  if (tharpExpectancy >= EXPECTANCYBASE) {
    resultString = "PASS";
  } else {
    resultString = "FAIL";
  }

  print("");
  
  string tradeListTitle = "\tTrade\tTime\t\t" + SYMBOLSETTING + "\t\t" + getBaseCurrencyName(SYMBOLSETTING) + "(per)\tProf" + getQuoteCurrencyName(SYMBOLSETTING) + "\t\tAcc";


  print("--------------------------------------------------------------------------------------------------------------------------");
  print(tradeListTitle);
  print("--------------------------------------------------------------------------------------------------------------------------");
  for (integer i = 0; i < sizeof(tradeLogList); i++) {
    print(tradeLogList[i]);
  }
  print(" ");
  print("--------------------------------------------------------------------------------------------------------------------------");
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

  return sellTotal - buyTotal - feeTotal;
}


string optimization() {
  # Connection Checking
  integer conTestStartTime = getCurrentTime() - 60 * 60 * 1000000;           # 1 hour before
  integer conTestEndTime = getCurrentTime();
  transaction conTestTrans[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, conTestStartTime, conTestEndTime);
  if (sizeof(conTestTrans) == 0) {
    print("Fetching Data failed. Please check the connection and try again later");
    exit;
  }

  string paramSetResult[];
  float profitResult[];

  integer RESOLSTARTInt = toInteger(substring(RESOLSTART, 0, strlength(RESOLSTART)-1));
  integer RESOLENDInt = toInteger(substring(RESOLEND, 0, strlength(RESOLEND)-1));
  integer RESOLSTEPInt = toInteger(substring(RESOLSTEP, 0, strlength(RESOLSTEP)-1));
  string RESOLSTARTUnitSymbol = substring(RESOLSTART, strlength(RESOLSTART)-1, 1);
  string RESOLENDUnitSymbol = substring(RESOLEND, strlength(RESOLEND)-1, 1);
  string RESOLSTEPUnitSymbol = substring(RESOLSTEP, strlength(RESOLSTEP)-1, 1);

  if (RESOLSTARTUnitSymbol != RESOLENDUnitSymbol || RESOLSTARTUnitSymbol != RESOLSTEPUnitSymbol) {
    print("Unit symbols for resolutions should be equal! Please retry again.");
    return "Resol unit error!";
  }

  string paramSet = "";
  string resolStr;
  float profit;
  integer paramSetNo = 0;

  print("======================================= Start optimization test ======================================");
  print("AFINITSTART : " + toString(AFINITSTART) + ", AFINITEND : " + toString(AFINITEND) + ", AFINITSTEP : " + toString(AFINITSTEP));
  print("AFMAXSTART : " + toString(AFMAXSTART) + ", AFMAXEND : " + toString(AFMAXEND) + ", AFMAXSTEP : " + toString(AFMAXSTEP));
  print("AFSTEPSTART : " + toString(AFSTEPSTART) + ", AFSTEPEND : " + toString(AFSTEPEND) + ", AFSTEPSTEP : " + toString(AFSTEPSTEP));
  print("RESOLSTART : " + RESOLSTART + ", RESOLEND : " + RESOLEND + ", RESOLSTEP : " + RESOLSTEP);
  print("AMOUNT : " + toString(AMOUNT));
  print("STARTDATETIME : " + toString(STARTDATETIME) + ", ENDDATETIME : " + toString(ENDDATETIME));
  print("=========================================================================================");
 
  # Fetching the historical trading data of given datatime period
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
  if (testTimeLength >  31536000000000) { # maximum backtest available length is 1 year = 365  * 24 * 60 * 60 * 1000000 ns
    print("You exceeded the maximum backtest period.\nPlease try again with another STARTDATETIME setting");
    
    return "Too long period error";
  }

  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();

  setChartDataTitle("PSAR - " + toString(AFINIT) + ", " + toString(AFMAX) + ", " + toString(AFSTEP));

  setCurrentSeriesName("Sell");
  configureScatter(true, "red", "red", 7.0);

  setCurrentSeriesName("Buy");
  configureScatter(true, "#7dfd63", "#187206", 7.0,);

  setCurrentSeriesName("Upword");
  configureScatter(true, "#faf849", "#6d6c0d", 7.0);

  setCurrentSeriesName("Downward");
  configureScatter(true, "#6beafd", "#095b67", 7.0,);

  setCurrentSeriesName("Direction");
  configureLine(true, "green", 2.0);

  for (float i = AFINITSTART; i <= AFINITEND; i += AFINITSTEP) {
    for (float j = AFMAXSTART; j <= AFMAXEND; j += AFMAXSTEP ) {
      for (float p = AFSTEPSTART; p <= AFSTEPEND; p += AFSTEPSTEP) {
        for (integer k = RESOLSTARTInt; k <= RESOLENDInt; k += RESOLSTEPInt) {
          paramSetNo ++;
          resolStr = toString(k);
          resolStr += RESOLSTARTUnitSymbol;
          
          paramSet = "AFINIT : " + toString(i) + ", AFMAX : " + toString(j) + ", AFSTEP : " + toString(p) + ", RESOL : " + resolStr;

          AFINIT = i;
          AFMAX = j;
          AFSTEP = p;
          RESOL = resolStr;

          print("------------------- Backtest Case " + toString(paramSetNo) + " : " + paramSet + " -------------------");
          profit = backtest();
          
          profitResult >> profit;
          paramSetResult >> paramSet;
          msleep(100);
        }
      }
    }
  }

  integer best = 0;
  for (integer p = 0; p < sizeof(profitResult); p++) {
    float temp = profitResult[p] - profitResult[best];
    if (temp > 0.0) {
      best = p;
    }
  }

  print(" ");

  print("================= Total optimization test result =================");

  print(" ");
  for (integer k=0; k< sizeof(paramSetResult); k++) {
    paramSetResult[k] = paramSetResult[k] + ", Profit : " + toString(profitResult[k]);
    print(paramSetResult[k]);
  }

  print("---------------- The optimized param set --------------");

  print(paramSetResult[best]);

  print("-------------------------------------------------------");
  print(" ");
  print("===========================================================");
  print(" ");

  return paramSetResult[best];
}


optimization();