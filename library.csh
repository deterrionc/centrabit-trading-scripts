#
# library.csh version 2.1.0 - Copyright(C) 2022 Centrabit.com ( Author: smartalina0915@gmail.com)
# 
#  - SMA(Simple Moving Average)          01/20/2023
#  - STDDEV(Standard Deviation)          01/20/2023
#  - bollingerUpperBand                  01/22/2023
#  - bollingerLowerBand                  01/22/2023
#  - EMA(Exponential Moving Average)     01/31/2023
#  - ATR(Average True Range)             09/20/2023
#  - getStocValue                        10/05/2023

# Script Name
script library;

# Dependancies
import Math;
import Strings;
import IO;

# SMA(Simple Moving Average) calculation
#  @ prototype
#      float SMA(float[]) 
#  @ params
#      prices: history prices in sma period
#  @ return
#      sma float value for the given array 
float SMA (float[] prices) {
  integer length = sizeof(prices);
  float sum = 0.0;
  float result = 0.0;
  
  for (integer i = 0; i < length; i++) {
      sum += prices[i];
  }
  float sma = (sum / toFloat(length));

  return sma;
}

# Standard Deviation calculation
#  @ prototype
#      float STDDEV(float, float[]) 
#  @ params
#      prices: history prices in sma period
#      sma: sma value
#  @ return
#      standard deviation for the given sma and array
float STDDEV (float[] prices, float sma) {
  integer length = sizeof(prices);
  float squaredDifferencesSum = 0.0;
  float meanOfSquaredDifferences = 0.0;

  # find the sum of the squared differences
  squaredDifferencesSum = 0.0;
  for (integer i = 0; i < length; i++) {
    squaredDifferencesSum += pow(prices[i] - sma, toFloat(2));
  }
  # take the mean of the squared differences
  meanOfSquaredDifferences = squaredDifferencesSum / toFloat(length);
  float stddev = sqrt(meanOfSquaredDifferences);

  return stddev;
}

# EMA(Exponential Moving Average) calculation
#  @ prototype
#      float EMA(float[]) 
#  @ params
#      prices: history prices in EMA period
#      N: number of days in EMA
#  @ return
#      EMA float value for the given array
float EMA (float[] prices, integer N) {
  float K = 2.0 / (toFloat(N) + 1.0);
  float sum = 0.0;
  float ema = 0.0;
  
  integer i;
  for (i = 0; i < N; i++) {
    sum += prices[N-i-1];      
  }

  ema = sum / toFloat(N);

  for (i = N; i < sizeof(prices); i++) {
    ema = prices[i] * K + ema * (1.0 - K);
  }
  return ema;
}

# EMAUpdate(Exponential Moving Average) calculation from last EMA
#  @ prototype
#      float EMAUpdate(float[]) 
#  @ params
#      newValue : the value added new
#      lastEMA: last ema value
#      N: number of days in EMA
#  @ return
#      EMA float value for the given array
float EMAUpdate (float newValue, float lastEMA, integer N) {
  float K = 2.0/(toFloat(N)+1.0);
  float newEMA = newValue * K + lastEMA * (1.0 - K);

  return newEMA;
}

# Bollinger upper band calculation
#  @ prototype
#      float bollingerUpperBand (float sma, float stdev, float k) 
#  @ params
#      prices: history prices in sma period
#      k: the number of standard deviations applied to the Bollinger Bands indicator
#  @ return
#      bollinger upper band value
float bollingerUpperBand (float[] prices, float sma, float stddev, float k) {
  return (sma + (k * stddev));
}

# Bollinger lower band calculation
#  @ prototype
#      float bollingerLowerBand (float sma, float stdev, float k) 
#  @ params
#      prices: history prices in sma period
#      k: the number of standard deviations applied to the Bollinger Bands indicator
#  @ return
#      bollinger upper band value
float bollingerLowerBand (float[] prices, float sma, float stddev, float k) {
  return (sma - (k * stddev));
}

# Bar resolution symbol interpretation
#  @ prototype
#      integer interpretResol(string symbol)
#  @ params
#      symbol: resolution symbol string like "1m", "3h", "2d", "1w", "1m" ....
#  @ return
#      time length in integer with unit of minute
integer interpretResol(string symbol) {
  integer resolution = toInteger(substring(symbol, 0, strlength(symbol)-1)); # 1m, 5m, 15m, 30min, 1h, 4h, 1d, 1w, 1M
  string unit = substring(symbol, strlength(symbol)-1, 1);

  if (unit == "h") {
    resolution = resolution * 60;
  }
  if (unit == "d") {
    resolution = resolution * 24 * 60;
  }
  if (unit == "w") {
    resolution = resolution * 7 * 24 * 60;
  }
  if (unit == "M") {
    resolution = resolution * 305 * 24 * 6; # means resolution * 30.5 * 24 * 60
  }

  return resolution;
}

# Min value fetching in integer array
#  @ prototype
#      integer minInArray(integer[] data)
#  @ params
#      data: source array
#  @ return
#      min value
integer minInArray(integer[] data) {
  integer m = data[0];

  for (integer i = 1; i < sizeof(data); i++) {
    if (data[i] < m)
      m = data[i];
  }
  return m;
}

# Max value fetching in integer array
#  @ prototype
#      integer maxInArray(integer[] data)
#  @ params
#      data: source array
#  @ return
#      max value
integer maxInArray(integer[] data) {
  integer m = data[0];

  for (integer i = 1; i < sizeof(data); i++) {
    if (data[i] > m)
      m = data[i];
  }
  return m;
}

# Min value fetching in float array
#  @ prototype
#      float fminInArray(float[] data)
#  @ params
#      data: source array
#  @ return
#      min value
float fminInArray(float[] data) {
  float m = data[0];

  for (integer i = 1; i < sizeof(data); i++) {
    if (data[i] < m)
      m = data[i];
  }
  return m;
}

# Max value fetching in float array
#  @ prototype
#      float fmaxInArray(float[] data)
#  @ params
#      data: source array
#  @ return
#      max value
float fmaxInArray(float[] data) {
  float m = data[0];

  for (integer i = 1; i < sizeof(data); i++) {
    if (data[i] > m)
      m = data[i];
  }
  return m;
}

# Generate a bar with given transaction array
#  @ prototype
#      bar generateBar(transaction[] data)
#  @ params
#      data: source array
#  @ return
#      bar
bar generateBar(transaction[] data) {
  bar b;

  if(sizeof(data) == 0) {
    print("Empty bar array passed to generateBar in library.");
    return b;
  }

  float prices[];
  for (integer i = 0; i < sizeof(data); i++) {
    prices >> data[i].price;
  }
  
  b.highPrice = fmaxInArray(prices);
  b.lowPrice = fminInArray(prices);
  b.openPrice = prices[0];
  b.closePrice = prices[sizeof(prices)-1];
  b.timestamp = data[0].tradeTime;
  return b;
}

# Calc ATR(Average True Range)
#  @ prototype
#      float ATR(bar data)
#  @ params
#      data: bar array
#  @ return
#      ATR value
float ATR(bar[] data) {
  integer barLength = sizeof(data);
  float trSum = 0.0;
  for (integer i = 1; i < barLength; i++) {
    bar current = data[i];
    bar last = data[i - 1];
    float tr1 = current.highPrice - current.lowPrice;
    float tr2 = current.highPrice - last.closePrice;
    float tr3 = last.closePrice - current.lowPrice;
    float tr = fmax(tr1, tr2);
    tr = fmax(tr, tr3);
    trSum += tr;
  }
  float atr = trSum / toFloat(barLength - 1);
  return atr;
}

# Get base currency string from symbol
#  @ prototype
#      string getBaseCurrencyName(string symbol)
#  @ params
#      symbol: symbol string like "LTC/BTC"
#  @ return
#      Base currency string
string getBaseCurrencyName(string symbol) {
  integer symbolLength = strlength(symbol);
  integer indicator = strfind(symbol, "/");
  string baseCurrencyName = substring(symbol, 0, indicator);

  return baseCurrencyName;
}

# Get quote currency string from symbol
#  @ prototype
#      string getQuoteCurrencyName(string symbol)
#  @ params
#      symbol: symbol string like "LTC/BTC"
#  @ return
#      Quote currency string
string getQuoteCurrencyName(string symbol) {
  integer symbolLength = strlength(symbol);
  integer indicator = strfind(symbol, "/");
  string baseCurrencyName = substring(symbol, indicator+1, symbolLength-indicator);

  return baseCurrencyName;
}

#  Print order logs for a transaction.
#  @prototype
#       void printOrderLogs(integer ID, string signal, integer time, float price, float amount, string extra)
#  @params
#       ID: The ID of the order
#       signal: The type of order (e.g., "BUY", "SELL")
#       time: Time the order was executed, in seconds since the epoch
#       price: The price at which the transaction occurred
#       amount: The amount of the asset that was transacted
#       extra: Additional information to include in the log (e.g., fee, comments)
#  @return
#       None
void printOrderLogs(integer ID, string signal, integer time, float price, float amount, string extra) {
  print(toString(ID) + " " + signal + "\t[" + timeToString(time, "yyyy-MM-dd hh:mm:ss") + "]: " + "Price " + toString(price) + "  Amount: " + toString(amount) + extra);
}

#  Print fill logs for a transaction.
#  @prototype
#       void printFillLogs(transaction t, string totalProfit)
#  @params
#       t: Transaction object containing details such as market, price, amount, and fee
#       totalProfit: A string representation of the total profit from the transaction; empty string if not applicable
#  @return
#       None
void printFillLogs(transaction t, string totalProfit) {
  if (totalProfit == "") {
    print(toString(t.marker) + " Filled \t[" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "]: " + "Price " + toString(t.price) + "  Amount: " + toString(t.amount) + ",  Fee: " + toString(t.fee));
  } else {
    print(toString(t.marker) + " Filled \t[" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "]: " + "Price " + toString(t.price) + "  Amount: " + toString(t.amount) + ",  Fee: " + toString(t.fee) + ",  Total profit: " + totalProfit);
  }
}

#  Get Stochastic Oscillator Value.
#  @prototype
#       void getStocValue(float[] data)
#  @params
#       Most recent trading prices
#  @return
#       Stochastic Oscillator Value
void getStocValue(float[] data) {
  integer dataLength = sizeof(data);
  float recentPrice = data[dataLength - 1];
  float lowest = fminInArray(data);
  float highest = fmaxInArray(data);
  float stoc = 100 * (recentPrice - lowest) / (highest - lowest);
  return stoc;
}