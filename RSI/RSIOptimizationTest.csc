# RSI (Relatvie Strengh Index) trading strategy optimization test - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script RSIOptimizationTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
integer PERIODSTART     = 14;
integer PERIODEND       = 14;
integer PERIODSTEP      = 1;
string  RESOLSTART      = "1h";
string  RESOLEND        = "3h";
string  RESOLSTEP       = "1h";
float   AMOUNT          = 1.0;                      # The amount of buy or sell order at once
string  STARTDATETIME   = "2023-03-01 00:00:00";    # Backtest start datetime
string  ENDDATETIME     = "now";                    # Backtest end datetime
float   EXPECTANCYBASE  = 0.1;                      # expectancy base
float   FEE             = 0.002;                    # trading fee as a decimal (0.2%)
#############################################

# Trading Variables
string  position        = "flat";
string  prevPosition    = "";    # "", "long", "short"
float   avgGain         = 0.0;
float   avgLoss         = 0.0;
float   lastPrice       = 0.0;
float   priceChange     = 0.0;
float   gain            = 0.0;
float   loss            = 0.0;
float   rs              = 0.0;
float   rsi             = 100.0;
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
float   baseCurrencyBalance   = getAvailableBalance(EXCHANGESETTING, getBaseCurrencyName(SYMBOLSETTING));
float   quoteCurrencyBalance  = getAvailableBalance(EXCHANGESETTING, getQuoteCurrencyName(SYMBOLSETTING));

# Additional needs in backtest mode
float   minFillOrderPercentage = 0.0;
float   maxFillOrderPercentage = 0.0;

integer PERIOD = 14;
string  RESOL           = "1m";                            # Bar resolution

transaction transForTest[];

# Starting MACD algo
setCurrentChartsExchange(EXCHANGESETTING);
setCurrentChartsSymbol(SYMBOLSETTING);

# Drawable flag
boolean drawable = false;

void onOwnOrderFilledTest(transaction t) {
  float amount = t.price * t.amount;
  feeTotal += t.fee;

  if (t.isAsk == false) {                # when sell order fillend
    sellTotal += amount;
    baseCurrencyBalance -= AMOUNT;
    quoteCurrencyBalance += amount;
  } else {                                 # when buy order fillend
    buyTotal += amount;
    baseCurrencyBalance += AMOUNT;
    quoteCurrencyBalance -= amount;
  }

  integer isOddOrder = t.marker % 2;
  integer tradeNumber = (t.marker-1) / 2 + 1;
  string tradeLog = "   ";

  if (isOddOrder == 0) {
    print(toString(t.marker) + " filled (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + toString(t.price) + " * " + toString(t.amount) + ",  fee: " + toString(t.fee) + ",  Total profit: " + toString(sellTotal - buyTotal - feeTotal));
    string tradeNumStr = toString(tradeNumber);
    for (integer i = 0; i < strlength(tradeNumStr); i++) {
      tradeLog += " ";
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

    string tradeResult;
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
    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(AMOUNT);
    tradeLogList >> tradeLog;
  }
}

void onPubOrderFilledTest(transaction t) {
  priceChange = t.price - lastPrice;
  gain = 0.0;
  loss = 0.0;

  if (priceChange > 0.0) {
      gain = priceChange;
  }
  if (priceChange < 0.0) {
      loss = fabs(priceChange);
  }

  avgGain = ((avgGain * toFloat(PERIOD-1)) + gain) / toFloat(PERIOD);
  avgLoss = ((avgLoss * toFloat(PERIOD-1)) + loss) / toFloat(PERIOD);
  rs = avgGain / avgLoss;
  if (avgLoss == 0.0) {
    rsi = 100.0;
  } else {
    rsi = 100.0 - (100.0 / (1.0 + rs));
  }

  # print("AVG loss is " + toString(avgLoss));

  if (rsi < 30.0) { # buy signal
    if (position == "short" || position == "flat") {
      currentOrderId++;
      print(toString(currentOrderId) + " buy order (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(t.price) + "  amount: "+ toString(AMOUNT));
  
      # emulating buy order filling
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price + t.price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
      filledTran.amount = AMOUNT;
      filledTran.fee = AMOUNT * t.price * FEE * 0.01;
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = true;
      onOwnOrderFilledTest(filledTran);

      if (position == "flat") {
        prevPosition = "long";
      }
      position = "long";
      buyCount ++;
      if (drawable) {
        setCurrentChartPosition("0");
        drawChartPointToSeries("Buy", t.tradeTime, t.price);
        drawChartPointToSeries("Direction", t.tradeTime, t.price);           
      }
    }
  } else if (rsi > 70.0) { # sell signal
    if (position == "long" || position == "flat") {
      currentOrderId++;
      print(toString(currentOrderId) + " sell order (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(t.price) + "  amount: "+ toString(AMOUNT));

      # emulating sell order filling
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
      filledTran.amount = AMOUNT;
      filledTran.fee = AMOUNT * t.price * FEE * 0.01;
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = false;
      onOwnOrderFilledTest(filledTran);
        
      if (position == "flat") {
        prevPosition = "short";
      }
      
      position = "short";
      sellCount ++;
      if (drawable) {
        setCurrentChartPosition("0");
        drawChartPointToSeries("Sell", t.tradeTime, t.price);
        drawChartPointToSeries("Direction", t.tradeTime, t.price);         
      } 
    }    
  }
  
  if(drawable) {
    setCurrentChartPosition("1");
    drawChartPointToSeries("RSI", t.tradeTime, rsi);    
  }
  
  lastPrice = t.price;
}

float backtest() {
  avgGain = 0.0;
  avgLoss = 0.0;
  lastPrice = 0.0;
  priceChange = 0.0;
  gain = 0.0;
  loss = 0.0;
  rs = 0.0;
  rsi = 100.0;

  position = "flat";
  prevPosition = "";    # "", "long", "short"

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
  baseCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getBaseCurrencyName(SYMBOLSETTING));
  quoteCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getQuoteCurrencyName(SYMBOLSETTING));

  integer resolution = interpretResol(RESOL);
  integer testStartTime = stringToTime(STARTDATETIME, "yyyy-MM-dd hh:mm:ss");
  integer currentTime = getCurrentTime();

  bar barData[] = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, testStartTime, PERIOD, resolution * 60 * 1000 * 1000);

  for (integer i = 1; i < sizeof(barData); i++) {
    priceChange = barData[i].closePrice - barData[i-1].closePrice;
    if (priceChange > 0.0) {
        gain += priceChange;
    }
    if (priceChange < 0.0) {
        loss += fabs(priceChange);
    }
  }
  avgGain = gain / toFloat(PERIOD);
  avgLoss = loss / toFloat(PERIOD);
  lastPrice = barData[sizeof(barData)-1].closePrice;
  rs = avgGain / avgLoss;
  if (avgLoss == 0.0) {
    rsi = 100.0;
  } else {
    rsi = 100.0 - (100.0 / (1.0 + rs));
  }

  delete barData;  

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

  integer cnt = sizeof(transForTest);
  integer step = resolution * 2;
  integer updateTicker = 0;
  integer msleepFlag = 0;


  integer timestampToStartLast24Hours = currentTime - 86400000000;  # 86400000000 = 24 * 3600 * 1000 * 1000
  integer lastUpdatedTimestamp = transForTest[0].tradeTime;

  integer timecounter = 0;
  delete tradeLogList;

  for (integer i = 0; i < cnt; i++) {
    if (transForTest[i].tradeTime < timestampToStartLast24Hours) {
      updateTicker = i % step;
      if (updateTicker ==0) {
        onPubOrderFilledTest(transForTest[i]);
        lastUpdatedTimestamp = transForTest[i].tradeTime;
      } 
      updateTicker ++;     
    } else {
      timecounter = transForTest[i].tradeTime - lastUpdatedTimestamp;
      if (timecounter > (resolution * 60 * 1000 * 1000)) {
        onPubOrderFilledTest(transForTest[i]);
        lastUpdatedTimestamp = transForTest[i].tradeTime;         
      }
    }

    if (i == (cnt - 1)) {
      if (sellCount != buyCount) {
        transaction t;
        currentOrderId++;
        if (prevPosition == "long") { # sell order emulation
          print(toString(currentOrderId) + " sell order (" + timeToString(transForTest[i].tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(transForTest[i].price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = false;
          onOwnOrderFilledTest(t);
          sellCount ++;
          if (drawable) {
            setCurrentChartPosition("0");
            drawChartPointToSeries("Sell", transForTest[i].tradeTime, transForTest[i].price);
            drawChartPointToSeries("Direction",transForTest[i].tradeTime, transForTest[i].price);              
          }
        } else { # buy order emulation
          print(toString(currentOrderId) + " buy order (" + timeToString(transForTest[i].tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(transForTest[i].price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price + transForTest[i].price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = true;
          onOwnOrderFilledTest(t);
          buyCount ++;
          if (drawable) {
            setCurrentChartPosition("0");
            drawChartPointToSeries("Buy", transForTest[i].tradeTime, transForTest[i].price);
            drawChartPointToSeries("Direction", transForTest[i].tradeTime, transForTest[i].price);               
          }
        }
      }
    }

    msleepFlag = i % 2000;
    if ( msleepFlag == 0) {
      msleep(20);    
    }
  }

  if (drawable)
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

  return sellTotal - buyTotal;
}

string Optimization() {
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
    return;
  }

  string paramSet = "";
  string resolStr;
  float profit;
  integer paramSetNo = 0;

  print("======================================= Start optimization test ======================================");
  print("PERIODSTART : " + toString(PERIODSTART) + ", PERIODEND : " + toString(PERIODEND) + ", PERIODSTEP : " + toString(PERIODSTEP));
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
    return;
  }

  print("Fetching transactions from " + STARTDATETIME + " to " + ENDDATETIME + "...");
  transForTest = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, testStartTime, testEndTime);

  clearCharts();

  setChartBarCount(10);
  setChartBarWidth(24 * 60 * 60 * 1000000);                                # 1 day 
  setChartTime(transForTest[0].tradeTime +  777600000000); # 10min * 9  

  
  setCurrentSeriesName("Sell");
  configureScatter(true, "red", "red", 7.0);
  setCurrentSeriesName("Buy");
  configureScatter(true, "#7dfd63", "#187206", 7.0,);

  setCurrentSeriesName("Direction");
  configureLine(true, "green", 2.0);

  setCurrentChartPosition("1");
  setChartDataTitle("RSI (" + toString(14) + ")");
  setCurrentSeriesName("RSI");
  configureLine(true, "purple", 2.0);
  setCurrentSeriesName("30");
  configureLine(true, "green", 2.0);
  setCurrentSeriesName("70");
  configureLine(true, "pink", 2.0);

  if (drawable) {
    setCurrentChartPosition("1");
    drawChartPointToSeries("30", testStartTime, 30.0);
    drawChartPointToSeries("30", testEndTime, 30.0);
    drawChartPointToSeries("70", testStartTime, 70.0);
    drawChartPointToSeries("70", testEndTime, 70.0);
    setChartsPairBuffering(true);    
  }
  
  for (integer i = PERIODSTART; i <= PERIODEND; i += PERIODSTEP) {
    for (integer k = RESOLSTARTInt; k <= RESOLENDInt; k += RESOLSTEPInt) {
      paramSetNo ++;
      resolStr = toString(k) + RESOLSTARTUnitSymbol;
      paramSet = "PERIOD : " + toString(i) + ", RESOL : " + resolStr;
      PERIOD = i;
      RESOL = resolStr;
      print("------------------- Bacttest Case " + toString(paramSetNo) + " : " + paramSet + " -------------------");
      profit = backtest();
      profitResult >> profit;
      paramSetResult >> paramSet;
      msleep(100);
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

Optimization();
