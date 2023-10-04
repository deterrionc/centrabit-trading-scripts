# Keltner trading strategy optimization test 2.1.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script KeltnerOptimizationTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING     = "Centrabit";
string  SYMBOLSETTING       = "LTC/BTC";
integer EMALENSTART         = 20;
integer EMALENEND           = 30;
integer EMALENSTEP          = 10;
float   ATRMULTIPLIERSTART  = 0.5;
float   ATRMULTIPLIEREND    = 0.7;
float   ATRMULTIPLIERSTEP   = 0.1;
integer ATRLENGTH           = 14;                      # ATR period length (must be over than 3)
string  RESOLSTART          = "1h";
string  RESOLEND            = "1h";
string  RESOLSTEP           = "1h";
float   EXPECTANCYBASE      = 0.1;                     # expectancy base
float   FEE                 = 0.01;                    # taker fee in percentages
float   AMOUNT              = 1.0;                     # The amount of buy or sell order at once
string  STARTDATETIME       = "2023-07-04 00:00:00";   # Backtest start datetime
string  ENDDATETIME         = "now";                   # Backtest end datetime
float   STOPLOSSAT          = 0.05;                    # Stoploss as fraction of price
boolean USETRAILINGSTOP     = false;
#############################################

# Keltner Variables
float   ema             = 0.0;
float   atr             = 0.0;
float   upperBand       = 0.0;
float   lowerBand       = 0.0;
float   emaPrices[];
bar     atrBars[];

# Trading Variables
string  position        = "flat";
string  prevPosition    = "";    # "", "long", "short"
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
float   lastPrice             = 0.0;
float   lastOwnOrderPrice     = 0.0;
transaction transForTest[];

# Stop-loss and trailing stop info
float lockedPriceForProfit = 0.0;

# Current running ema, ATRMULTIPLIER, resol
integer EMALEN          = 20;                       # EMA period length
float   ATRMULTIPLIER   = 0.5;                      # Standard Deviation
string  RESOL           = "1h";                     # Bar resolution

# Drawable flag
boolean drawable = false;
transaction transactions[];

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
    for (integer i=0; i<strlength(tradeNumStr); i++) {
      tradeLog += " ";
    }
    float profit;
    if (t.isAsk == false) {
      profit = amount - entryAmount - t.fee - entryFee;
      tradeLog += "\tLX  ";
    } else {
      profit = entryAmount - amount - t.fee - entryFee;
      tradeLog += "\tSX  ";
    }

    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(profit) + "\t" + toString(sellTotal - buyTotal - feeTotal);

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
      tradeLog += "\tSE  ";
    } else {
      tradeLog += "\tLE  ";
    }
    entryAmount = amount;
    entryFee = t.fee;
    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t" + toString(AMOUNT);

    tradeLogList >> tradeLog;
  }
}

boolean stopLossTick(integer timeStamp, float price) {
  if (position == "flat" || STOPLOSSAT <= 0.0) {
    return false;
  }

  float limitPrice;
  float amount;
  float filledPrice;
  if (position == "long" && price < lowerBand) {
    limitPrice = lastOwnOrderPrice * (1.0 - STOPLOSSAT);
    if (price < limitPrice) {
      currentOrderId++;
      print(toString(currentOrderId) + " sell order (" + timeToString(timeStamp, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(price) + "  amount: "+ toString(AMOUNT) + "  @@@ StopLoss order @@@");

      # emulating sell order filling
      transaction t;
      t.id = currentOrderId;
      t.marker = currentOrderId;
      t.price = price;
      t.amount = AMOUNT;
      t.fee = AMOUNT*price*FEE * 0.01;
      t.tradeTime = timeStamp;
      t.isAsk = false;
      onOwnOrderFilledTest(t);

      drawChartPointToSeries("Sell", timeStamp, price);
      drawChartPointToSeries("Direction", timeStamp, price); 
      sellCount ++;
      position = "flat";
      return true;
    }
  } else if (position == "short" && price > upperBand) {
    limitPrice = lastOwnOrderPrice * (1.0 + STOPLOSSAT);
    if (price > limitPrice ) {
      currentOrderId ++;
      print(toString(currentOrderId) + " buy order (" + timeToString(timeStamp, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(price) + "  amount: "+ toString(AMOUNT) + "  @@@ StopLoss order @@@");

      # emulating buy order filling
      transaction t;
      t.id = currentOrderId;
      t.marker = currentOrderId;
      t.price = price;
      t.amount = AMOUNT;
      t.fee = AMOUNT*price*FEE * 0.01;
      t.tradeTime = timeStamp;
      t.isAsk = true;
      onOwnOrderFilledTest(t);

      drawChartPointToSeries("Buy", timeStamp, price);
      drawChartPointToSeries("Direction", timeStamp, price); 
      buyCount ++;  
      position = "flat";
      return true;
    }
  }
  return false;
}

boolean trailingStopTick(float price) {
  if (USETRAILINGSTOP == false)
    return false;
  if (price < lowerBand) {  # if the position is in  
    if (lockedPriceForProfit == 0.0 || lockedPriceForProfit < price) {
      lockedPriceForProfit = price;
      return true;
    }
  }
  if (price > upperBand) {
    if (lockedPriceForProfit == 0.0 || lockedPriceForProfit > price) {
      lockedPriceForProfit = price;
      return true;
    }
  }
  lockedPriceForProfit = 0.0;
  return false;
}

void updateKeltnerParams(transaction t) {
  delete transactions[0];
  delete atrBars[0];
  delete emaPrices[0];

  emaPrices >> t.price;
  transactions >> t;
  bar tempBar = generateBar(transactions);
  atrBars >> tempBar;

  ema = EMA(emaPrices, EMALEN);
  atr = ATR(atrBars);
  upperBand = ema + ATRMULTIPLIER * atr;
  lowerBand = ema - ATRMULTIPLIER * atr;
}

void keltnerTick(integer tradeTime, float price) {
  drawChartPointToSeries("Middle", tradeTime, ema);
  drawChartPointToSeries("Upper", tradeTime, upperBand);
  drawChartPointToSeries("Lower", tradeTime, lowerBand);

  if (stopLossTick(tradeTime, price))
    return;

  if (trailingStopTick(price))
    return;

  string signal = "";

  if (price > upperBand && position != "short") {
    if (prevPosition == "")
      signal = "sell";
    else if (position == "long")
      signal = "sell";
    else if (position == "flat" && prevPosition == "short")
      signal = "sell";
  }
  if (price < lowerBand && position != "long") {
      if (prevPosition == "")
      signal = "buy";
    else if (position == "short")
      signal = "buy";
    else if (position == "flat" && prevPosition == "long")
      signal = "buy";
  }

  if (signal == "sell") {
    # Sell oder execution
    currentOrderId ++;
    print(toString(currentOrderId) + " sell order (" + timeToString(tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(price) + "  amount: "+ toString(AMOUNT));

    # emulating sell order filling
    transaction t;
    t.id = currentOrderId;
    t.marker = currentOrderId;
    t.price = price;
    t.amount = AMOUNT;
    t.fee = AMOUNT*price*FEE * 0.01;
    t.tradeTime = tradeTime;
    t.isAsk = false;
    onOwnOrderFilledTest(t);

    # drawing sell point and porit or loss line
    drawChartPointToSeries("Sell", tradeTime, price);
    drawChartPointToSeries("Direction", tradeTime, price);
    # Update the last own order price
    lastOwnOrderPrice = price;
    if (position == "flat" && prevPosition == "") {
      prevPosition = "short";
    }
    position = "short";
    sellCount ++;
  }
  if (signal == "buy") {
    # buy order execution
    currentOrderId ++;
    print(toString(currentOrderId) + " buy order (" + timeToString(tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(price) + "  amount: "+ toString(AMOUNT));

    # emulating buy order filling
    transaction t;
    t.id = currentOrderId;
    t.marker = currentOrderId;
    t.price = price;
    t.amount = AMOUNT;
    t.fee = AMOUNT*price*FEE * 0.01;
    t.tradeTime = tradeTime;
    t.isAsk = true;
    onOwnOrderFilledTest(t);
        
    # drawing buy point and porit or loss line
    drawChartPointToSeries("Buy", tradeTime, price);
    drawChartPointToSeries("Direction", tradeTime, price);
    # Update the last own order price
    lastOwnOrderPrice = price;
    if (position == "flat" && prevPosition == "") {
      prevPosition = "long";
    }   
    position = "long";
    buyCount ++;  
  }
}

void onPubOrderFilledTest(transaction t) {
  transactions >> t;
  keltnerTick(t.tradeTime, t.price);
}

float backtest() {
  integer resolution = interpretResol(RESOL);
  integer testStartTime = stringToTime(STARTDATETIME, "yyyy-MM-dd hh:mm:ss");
  integer currentTime = getCurrentTime();

  print("Preparing Bars in Period...");
  bar barsInPeriod[] = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, testStartTime, EMALEN, resolution * 60 * 1000 * 1000);
  integer barSize = sizeof(barsInPeriod);

  currentOrderId = 0;
  buyTotal = 0.0;
  buyCount = 0;
  sellTotal = 0.0;
  sellCount = 0;
  feeTotal = 0.0;
  prevPosition = "";
  delete emaPrices;
  delete atrBars;

  for (integer i = 0; i < ATRLENGTH; i++) {
    transaction tempTrans[];
    for (integer j = i; j < (i + EMALEN); j++) {
      tempTrans >> transForTest[j];
    }
    bar tempBar = generateBar(tempTrans);
    atrBars >> tempBar;
  }

  for (integer i = 0; i < EMALEN; i++) {
    transaction tempTran = transForTest[ATRLENGTH + i];
    transactions >> tempTran;
    emaPrices >> tempTran.price;
  }

  ema = EMA(emaPrices, EMALEN);
  atr = ATR(atrBars);
  upperBand = ema + ATRMULTIPLIER * atr;
  lowerBand = ema - ATRMULTIPLIER * atr;

  # ema = EMA(emaPrices, EMALEN);
  # atr = ATR(barsInPeriod[barSize-2], barsInPeriod[barSize-1]);
  # upperBand = ema + ATRMULTIPLIER * atr;
  # lowerBand = ema - ATRMULTIPLIER * atr;

  print("Initial EMA :" + toString(ema));
  print("Initial ATR :" + toString(atr));
  print("Initial keltnerUpperBand :" + toString(upperBand));
  print("Initial keltnerLowerBand :" + toString(lowerBand));

  integer cnt = sizeof(transForTest);
  integer step = resolution * 2;
  integer updateTicker = 0;
  integer msleepFlag = 0;

  integer timestampToStartLast24Hours = currentTime - 86400000000;  # 86400000000 = 24 * 3600 * 1000 * 1000
  integer lastUpdatedTimestamp = transForTest[0].tradeTime;

  integer timecounter = 0;
  delete tradeLogList;

  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();

  print("test progressing...");
  if (drawable == true) {
    setChartBarCount(10);
    setChartBarWidth(24 * 60 * 60 * 1000000);                                # 1 day 
    setChartTime(transForTest[0].tradeTime +  9 * 24 * 60 * 60 * 1000000);      # 9 days

    setChartDataTitle("Keltner - " + toString(EMALEN) + ", " + toString(ATRMULTIPLIER));

    setCurrentSeriesName("Sell");
    configureScatter(true, "red", "red", 7.0);
    setCurrentSeriesName("Buy");
    configureScatter(true, "#7dfd63", "#187206", 7.0,);
    setCurrentSeriesName("Direction");
    configureLine(true, "green", 2.0);
    setCurrentSeriesName("Middle");
    configureLine(true, "grey", 2.0);
    setCurrentSeriesName("Upper");
    configureLine(true, "#0095fd", 2.0);
    setCurrentSeriesName("Lower");
    configureLine(true, "#fd4700", 2.0);  
    
    setChartsPairBuffering(true);    
  }

  for (integer i = 0; i < cnt; i++) {
    onPubOrderFilledTest(transForTest[i]);
    if (transForTest[i].tradeTime < timestampToStartLast24Hours) {
      updateTicker = i % step;
      if (updateTicker ==0 && i != 0) {
        updateKeltnerParams(transForTest[i]);
        lastUpdatedTimestamp = transForTest[i].tradeTime;
      }      
      updateTicker ++;     
    } else {
        timecounter = transForTest[i].tradeTime - lastUpdatedTimestamp;
        if (timecounter > (resolution * 60 * 1000 * 1000)) {
          updateKeltnerParams(transForTest[i]);
          lastUpdatedTimestamp = transForTest[i].tradeTime;         
        }
    }

    if (i == (cnt - 1)) {
      if (sellCount != buyCount) {
        transaction t;
        currentOrderId++;
        if (prevPosition == "long") { # sell order emulation
          if (drawable == true)
            print(toString(currentOrderId) + " sell order (" + timeToString(transForTest[i].tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(transForTest[i].price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price;
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = false;
          onOwnOrderFilledTest(t);
          sellCount ++;
          if (drawable == true) {
            drawChartPointToSeries("Sell", transForTest[i].tradeTime, transForTest[i].price);
            drawChartPointToSeries("Direction", transForTest[i].tradeTime, transForTest[i].price);             
          }
        } else { # buy order emulation
          if (drawable == true)
            print(toString(currentOrderId) + " buy order (" + timeToString(transForTest[i].tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(transForTest[i].price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price;
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = true;
          onOwnOrderFilledTest(t);
          buyCount ++;
          if (drawable == true) {
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

  if (drawable == true)
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
  
  string tradeLogListTitle = "Trade\tTime\t\t" + SYMBOLSETTING + "\tMax" + getBaseCurrencyName(SYMBOLSETTING) + "\tProf" + getQuoteCurrencyName(SYMBOLSETTING) + "\tAcc\tDrawdown";

  print("--------------------------------------------------------------------------------------------------------------------------");
  print(tradeLogListTitle);
  print("--------------------------------------------------------------------------------------------------------------------------");
  for (integer i=0; i<sizeof(tradeLogList); i++) {
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

string optimization() {
  string paramSetResult[];
  float profitResult[];

  # Connection Checking
  integer conTestStartTime = getCurrentTime() - 60 * 60 * 1000000;           # 1 hour before
  integer conTestEndTime = getCurrentTime();
  transaction conTestTrans[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, conTestStartTime, conTestEndTime);
  if (sizeof(conTestTrans) == 0) {
    print("Fetching Data failed. Please check the connection and try again later");
    exit;
  }

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
  print("EMALENSTART : " + toString(EMALENSTART) + ", EMALENEND : " + toString(EMALENEND) + ", EMALENSTEP : " + toString(EMALENSTEP));
  print("ATRMULTIPLIERSTART : " + toString(ATRMULTIPLIERSTART) + ", ATRMULTIPLIEREND : " + toString(ATRMULTIPLIEREND) + ", ATRMULTIPLIERSTEP : " + toString(ATRMULTIPLIERSTEP));
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

  for (integer i = EMALENSTART; i <= EMALENEND; i += EMALENSTEP) {
    for (float j = ATRMULTIPLIERSTART; j <= ATRMULTIPLIEREND; j += ATRMULTIPLIERSTEP ) {
      for (integer k = RESOLSTARTInt; k <= RESOLENDInt; k += RESOLSTEPInt) {
        paramSetNo ++;
        resolStr = toString(k);
        resolStr = strinsert(resolStr, strlength(resolStr), RESOLSTARTUnitSymbol);
        
        paramSet = "EMALEN : ";
        paramSet = strinsert(paramSet, 8, toString(i));
        paramSet = strinsert(paramSet, strlength(paramSet)-1, ", ATRMULTIPLIER : ");
        paramSet= strinsert(paramSet, strlength(paramSet)-1, toString(j));
        paramSet= strinsert(paramSet, strlength(paramSet)-1, ", RESOL : ");
        paramSet= strinsert(paramSet, strlength(paramSet)-1, resolStr);

        EMALEN = i;
        ATRMULTIPLIER = j;
        RESOL = resolStr;

        print("------------------- Bacttest Case " + toString(paramSetNo) + " : " + paramSet + " -------------------");
        profit = backtest();
        profitResult >> profit;
        paramSetResult >> paramSet;
        msleep(100);
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
    paramSetResult[k] = strinsert(paramSetResult[k], strlength(paramSetResult[k])-1, ", Profit : ");
    paramSetResult[k] = strinsert(paramSetResult[k], strlength(paramSetResult[k])-1, toString(profitResult[k]));
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