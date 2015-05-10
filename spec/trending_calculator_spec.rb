# coding: utf-8
require_relative "support/factory_girl"
require_relative "../trending_calculator"

HISTORY_STR =
"""
Date,Open,High,Low,Close,Volume,Adj Close
2015-05-06,13.90,14.15,13.59,13.65,5308700,13.65
2015-05-05,14.58,14.69,13.86,13.86,9663400,13.86
2015-05-04,14.55,14.75,14.28,14.58,6893600,14.58
2015-05-01,14.67,14.67,14.67,14.67,000,14.67
2015-04-30,15.03,15.13,14.65,14.67,7468500,14.67
2015-04-29,14.92,15.17,14.74,15.03,6412700,15.03
2015-04-28,15.50,15.67,14.54,14.88,11261200,14.88
2015-04-27,15.25,16.10,15.00,15.70,17324600,15.70
2015-04-24,14.60,15.30,14.53,15.20,13903300,15.20
2015-04-23,14.95,15.09,14.50,14.87,13576300,14.87
2015-04-22,14.78,15.02,14.72,14.95,16638500,14.95
2015-04-21,14.30,14.78,14.20,14.78,7642800,14.78
2015-04-20,14.70,14.70,14.23,14.27,8007000,14.27
2015-04-17,15.03,15.31,14.67,14.85,7485800,14.85
2015-04-16,14.57,15.16,13.99,15.03,8475500,15.03
2015-04-15,14.81,15.03,14.00,14.57,8931000,14.57
2015-04-14,15.40,15.89,15.05,15.09,15885000,15.09
2015-04-13,14.20,15.59,14.20,15.59,15522000,15.59
2015-04-10,13.75,14.21,13.71,14.17,6869300,14.17
2015-04-09,14.05,14.20,13.52,13.77,9772800,13.77
2015-04-08,14.61,14.68,14.07,14.11,9517300,14.11
2015-04-07,14.48,14.74,14.38,14.61,6606900,14.61
2015-04-06,14.48,14.48,14.48,14.48,000,14.48
2015-04-03,14.06,14.48,13.93,14.48,7740700,14.48
2015-04-02,14.06,14.11,13.89,14.05,6005500,14.05
2015-04-01,13.75,14.06,13.75,14.00,6399300,14.00
2015-03-31,13.95,14.06,13.71,13.75,6665700,13.75
2015-03-30,13.60,14.07,13.60,13.97,9651100,13.97
2015-03-27,13.25,13.73,13.24,13.59,8879000,13.59
2015-03-26,13.05,13.33,12.98,13.29,9221400,13.29
2015-03-25,13.09,13.14,12.92,13.11,5908400,13.11
2015-03-24,13.35,13.42,12.80,13.09,9154900,13.09
2015-03-23,13.28,13.48,13.17,13.37,6523000,13.37
2015-03-20,13.39,13.45,13.21,13.24,5945000,13.24
2015-03-19,13.09,13.43,13.00,13.36,9023500,13.36
2015-03-18,13.00,13.16,12.89,13.15,8638600,13.15
2015-03-17,12.91,13.19,12.90,13.07,10737500,13.07
2015-03-16,12.95,13.34,12.91,13.22,4863100,13.22
2015-03-13,12.82,13.05,12.82,12.85,2786800,12.85
2015-03-12,12.84,12.89,12.68,12.80,3095600,12.80
2015-03-11,12.93,13.04,12.67,12.78,4076600,12.78
2015-03-10,12.58,13.08,12.58,12.93,5230700,12.93
2015-03-09,12.45,12.66,12.32,12.63,3425300,12.63
2015-03-06,12.65,12.87,12.50,12.53,4161500,12.53
2015-03-05,12.57,12.72,12.46,12.60,4132600,12.60
2015-03-04,12.20,12.61,12.18,12.55,5087600,12.55
2015-03-03,12.33,12.34,12.15,12.20,4007700,12.20
2015-03-02,12.29,12.49,12.23,12.34,4944100,12.34
2015-02-27,12.21,12.31,12.13,12.20,2687000,12.20
2015-02-26,12.04,12.24,12.03,12.21,2965000,12.21
2015-02-25,12.10,12.13,12.01,12.03,2033700,12.03
2015-02-24,12.11,12.11,12.11,12.11,000,12.11
2015-02-23,12.11,12.11,12.11,12.11,000,12.11
2015-02-20,12.11,12.11,12.11,12.11,000,12.11
2015-02-19,12.11,12.11,12.11,12.11,000,12.11
2015-02-18,12.11,12.11,12.11,12.11,000,12.11
2015-02-17,12.06,12.27,12.05,12.11,2537500,12.11
2015-02-16,11.94,12.07,11.86,12.06,2207700,12.06
2015-02-13,11.75,12.01,11.75,11.93,2736900,11.93
2015-02-12,11.70,11.76,11.68,11.71,1266500,11.71
2015-02-11,11.68,11.79,11.64,11.69,1342100,11.69
2015-02-10,11.55,11.68,11.51,11.64,1227000,11.64
2015-02-09,11.58,11.73,11.51,11.58,1325900,11.58
2015-02-06,11.72,11.84,11.64,11.67,1801700,11.67
2015-02-05,12.01,12.05,11.73,11.76,2568600,11.76
2015-02-04,12.09,12.09,11.85,11.89,2090600,11.89
2015-02-03,11.98,12.03,11.85,12.02,2320300,12.02
2015-02-02,11.77,11.95,11.76,11.89,1733400,11.89
2015-01-30,11.92,11.99,11.79,11.89,2510700,11.89
2015-01-29,12.20,12.25,11.88,11.90,4556100,11.90
2015-01-28,12.26,12.43,12.16,12.25,3897700,12.25
2015-01-27,12.20,12.32,12.02,12.30,5681900,12.30
2015-01-26,11.96,12.20,11.72,12.20,7316500,12.20
2015-01-23,12.47,12.51,12.24,12.30,3055100,12.30
2015-01-22,12.40,12.53,12.30,12.44,4557200,12.44
2015-01-21,11.95,12.39,11.95,12.35,4371900,12.35
2015-01-20,11.65,11.95,11.65,11.95,3190300,11.95
2015-01-19,12.19,12.28,11.43,11.62,5768400,11.62
2015-01-16,11.98,12.44,11.93,12.39,4175800,12.39
2015-01-15,11.85,11.98,11.80,11.98,1943200,11.98
2015-01-14,12.06,12.07,11.80,11.84,2508300,11.84
2015-01-13,11.80,12.07,11.76,12.05,2390200,12.05
2015-01-12,12.19,12.19,11.76,11.87,4222600,11.87
2015-01-09,12.26,12.51,12.22,12.26,3343800,12.26
2015-01-08,12.56,12.58,12.19,12.27,4468600,12.27
2015-01-07,12.74,12.89,12.40,12.55,6147300,12.55
2015-01-06,12.60,13.15,12.46,12.84,7463500,12.84
2015-01-05,12.41,12.74,12.40,12.57,7104000,12.57
2015-01-02,12.52,12.52,12.52,12.52,000,12.52
2015-01-01,12.52,12.52,12.52,12.52,000,12.52
2014-12-31,12.77,12.77,12.35,12.52,8426100,12.52
2014-12-30,11.76,12.90,11.75,12.80,14128100,12.80
2014-12-29,11.95,12.19,11.72,11.76,5457100,11.76
2014-12-26,11.85,12.05,11.83,11.95,4763400,11.95
2014-12-25,11.28,12.01,11.28,11.88,6341200,11.88
2014-12-24,11.12,11.32,11.11,11.31,2712000,11.31
2014-12-23,11.11,11.30,11.02,11.07,2039600,11.07
2014-12-22,11.54,11.55,11.00,11.14,4935400,11.14
2014-12-19,11.72,11.74,11.26,11.55,4282400,11.55
2014-12-18,11.76,11.88,11.68,11.74,2656400,11.74
2014-12-17,11.99,12.00,11.68,11.75,4059300,11.75
2014-12-16,12.08,12.16,11.90,12.04,3685100,12.04
2014-12-15,11.92,12.23,11.75,12.17,4653000,12.17
2014-12-12,11.85,12.02,11.78,11.93,4497900,11.93
2014-12-11,11.40,11.94,11.30,11.85,6683400,11.85
2014-12-10,11.12,11.48,11.07,11.43,3767100,11.43
2014-12-09,11.58,11.67,10.99,11.09,6261500,11.09
2014-12-08,11.48,11.73,11.47,11.69,4692900,11.69
2014-12-05,12.16,12.16,11.35,11.55,8345300,11.55
2014-12-04,12.35,12.35,12.10,12.15,7109200,12.15
2014-12-03,11.74,12.28,11.65,12.24,8543500,12.24
2014-12-02,11.65,11.76,11.60,11.76,4466700,11.76
2014-12-01,11.43,11.93,11.43,11.64,8246100,11.64
2014-11-28,11.49,11.51,11.30,11.36,4045100,11.36
2014-11-27,11.40,11.57,11.36,11.49,4045500,11.49
2014-11-26,11.43,11.50,11.28,11.38,2822800,11.38
2014-11-25,11.28,11.50,11.26,11.42,3722700,11.42
2014-11-24,11.22,11.34,11.16,11.27,3564100,11.27
2014-11-21,10.96,11.14,10.96,11.12,2853800,11.12
2014-11-20,11.01,11.05,10.92,10.95,1736500,10.95
2014-11-19,11.00,11.15,10.91,11.03,2343600,11.03
2014-11-18,10.91,11.13,10.91,11.00,2038300,11.00
2014-11-17,10.85,10.97,10.73,10.95,2118900,10.95
2014-11-14,10.83,10.86,10.71,10.78,2199500,10.78
2014-11-13,11.10,11.12,10.83,10.83,3267600,10.83
2014-11-12,10.82,11.10,10.79,11.08,2442600,11.08
2014-11-11,11.34,11.39,10.78,10.87,5430300,10.87
2014-11-10,11.15,11.41,11.15,11.32,3200400,11.32
"""

HISTORY_STR2=
  """
Date,Open,High,Low,Close,Volume,Adj Close
2015-05-08,10.84,10.84,10.84,10.84,000,10.84
2015-05-07,10.84,10.84,10.84,10.84,000,10.84
2015-05-06,10.84,10.84,10.84,10.84,000,10.84
2015-05-05,10.84,10.84,10.84,10.84,000,10.84
2015-05-04,10.84,10.84,10.84,10.84,000,10.84
2015-05-01,10.84,10.84,10.84,10.84,000,10.84
2015-04-30,10.84,10.84,10.84,10.84,000,10.84
2015-04-29,10.84,10.84,10.84,10.84,000,10.84
2015-04-28,10.84,10.84,10.84,10.84,000,10.84
2015-04-27,10.84,10.84,10.84,10.84,000,10.84
2015-04-24,10.84,10.84,10.84,10.84,000,10.84
2015-04-23,10.84,10.84,10.84,10.84,000,10.84
2015-04-22,10.84,10.84,10.84,10.84,000,10.84
2015-04-21,10.84,10.84,10.84,10.84,000,10.84
2015-04-20,10.84,10.84,10.84,10.84,000,10.84
2015-04-17,10.84,10.84,10.84,10.84,000,10.84
2015-04-16,10.84,10.84,10.84,10.84,000,10.84
2015-04-15,10.84,10.84,10.84,10.84,000,10.84
2015-04-14,10.84,10.84,10.84,10.84,000,10.84
2015-04-13,10.84,10.84,10.84,10.84,000,10.84
2015-04-10,10.84,10.84,10.84,10.84,000,10.84
2015-04-09,10.84,10.84,10.84,10.84,000,10.84
2015-04-08,10.84,10.84,10.84,10.84,000,10.84
2015-04-07,10.84,10.84,10.84,10.84,000,10.84
2015-04-06,10.84,10.84,10.84,10.84,000,10.84
2015-04-03,10.84,10.84,10.84,10.84,000,10.84
2015-04-02,10.84,10.84,10.84,10.84,000,10.84
2015-04-01,10.84,10.84,10.84,10.84,000,10.84
2015-03-31,10.84,10.84,10.84,10.84,000,10.84
2015-03-30,10.84,10.84,10.84,10.84,000,10.84
2015-03-27,10.84,10.84,10.84,10.84,000,10.84
2015-03-26,10.84,10.84,10.84,10.84,000,10.84
2015-03-25,10.84,10.84,10.84,10.84,000,10.84
2015-03-24,10.84,10.84,10.84,10.84,000,10.84
2015-03-23,10.84,10.84,10.84,10.84,000,10.84
2015-03-20,10.84,10.84,10.84,10.84,000,10.84
2015-03-19,10.84,10.84,10.84,10.84,000,10.84
2015-03-18,10.84,10.84,10.84,10.84,000,10.84
2015-03-17,10.84,10.84,10.84,10.84,000,10.84
2015-03-16,10.84,10.84,10.84,10.84,000,10.84
2015-03-13,10.84,10.84,10.84,10.84,000,10.84
2015-03-12,10.84,10.84,10.84,10.84,000,10.84
2015-03-11,10.84,10.84,10.84,10.84,000,10.84
2015-03-10,10.84,10.84,10.84,10.84,000,10.84
2015-03-09,10.84,10.84,10.84,10.84,000,10.84
2015-03-06,10.84,10.84,10.84,10.84,000,10.84
2015-03-05,10.84,10.84,10.84,10.84,000,10.84
2015-03-04,10.84,10.84,10.84,10.84,000,10.84
2015-03-03,10.84,10.84,10.84,10.84,000,10.84
2015-03-02,10.84,10.84,10.84,10.84,000,10.84
2015-02-27,10.84,10.84,10.84,10.84,000,10.84
2015-02-26,10.84,10.84,10.84,10.84,000,10.84
2015-02-25,10.84,10.84,10.84,10.84,000,10.84
2015-02-24,10.84,10.84,10.84,10.84,000,10.84
2015-02-23,10.84,10.84,10.84,10.84,000,10.84
2015-02-20,10.84,10.84,10.84,10.84,000,10.84
2015-02-19,10.84,10.84,10.84,10.84,000,10.84
2015-02-18,10.84,10.84,10.84,10.84,000,10.84
2015-02-17,10.84,10.84,10.84,10.84,000,10.84
2015-02-16,10.84,10.84,10.84,10.84,000,10.84
2015-02-13,10.84,10.84,10.84,10.84,000,10.84
2015-02-12,10.84,10.84,10.84,10.84,000,10.84
2015-02-11,10.84,10.84,10.84,10.84,000,10.84
2015-02-10,10.84,10.84,10.84,10.84,000,10.84
2015-02-09,10.84,10.84,10.84,10.84,000,10.84
2015-02-06,10.84,10.84,10.84,10.84,000,10.84
2015-02-05,10.84,10.84,10.84,10.84,000,10.84
2015-02-04,10.84,10.84,10.84,10.84,000,10.84
2015-02-03,10.84,10.84,10.84,10.84,000,10.84
2015-02-02,10.84,10.84,10.84,10.84,000,10.84
2015-01-30,10.84,10.84,10.84,10.84,000,10.84
2015-01-29,10.84,10.84,10.84,10.84,000,10.84
2015-01-28,10.84,10.84,10.84,10.84,000,10.84
2015-01-27,10.94,11.08,10.82,10.84,4505100,10.84
2015-01-26,10.76,11.18,10.70,11.03,12876300,11.03
2015-01-23,10.87,11.06,10.65,10.80,15640300,10.80
2015-01-22,10.20,10.96,10.12,10.82,20363400,10.82
2015-01-21,10.11,10.27,10.10,10.17,8587600,10.17
2015-01-20,9.85,10.20,9.82,10.15,9192500,10.15
2015-01-19,10.00,10.12,9.56,9.90,12169100,9.90
2015-01-16,10.16,10.30,9.98,10.24,11406700,10.24
2015-01-15,10.28,10.37,10.09,10.17,7571600,10.17
2015-01-14,9.87,10.42,9.86,10.23,16799400,10.23
2015-01-13,9.59,10.00,9.53,9.97,8963300,9.97
2015-01-12,10.02,10.02,9.65,9.70,9730000,9.70
2015-01-09,10.14,10.38,9.99,10.02,15289400,10.02
2015-01-08,10.02,10.36,9.99,10.14,22372700,10.14
2015-01-07,9.66,9.96,9.58,9.95,14959800,9.95
2015-01-06,9.50,9.71,9.48,9.67,9272300,9.67
2015-01-05,9.26,9.67,9.22,9.62,12406000,9.62
2015-01-02,9.30,9.30,9.30,9.30,000,9.30
2015-01-01,9.30,9.30,9.30,9.30,000,9.30
2014-12-31,9.13,9.33,9.09,9.30,5510700,9.30
2014-12-30,9.13,9.26,8.90,9.17,4044900,9.17
2014-12-29,9.15,9.27,9.06,9.14,3973600,9.14
2014-12-26,9.25,9.33,9.13,9.16,6038900,9.16
2014-12-25,9.16,9.34,9.11,9.27,3170800,9.27
2014-12-24,9.17,9.24,9.09,9.17,2829200,9.17
2014-12-23,9.38,9.41,9.05,9.10,3820400,9.10
2014-12-22,9.26,9.34,8.89,9.30,8212800,9.30
2014-12-19,9.38,9.38,9.05,9.16,8151700,9.16
2014-12-18,9.39,9.45,9.30,9.40,3329200,9.40
2014-12-17,9.62,9.68,9.30,9.38,5972000,9.38
2014-12-16,9.61,9.67,9.58,9.62,4839600,9.62
2014-12-15,9.65,9.72,9.51,9.68,6392400,9.68
2014-12-12,9.63,9.69,9.44,9.58,7985300,9.58
2014-12-11,9.48,9.65,9.37,9.59,7060000,9.59
2014-12-10,9.23,9.58,9.19,9.50,5294000,9.50
2014-12-09,9.38,9.47,9.25,9.26,8480500,9.26
2014-12-08,9.43,9.58,9.29,9.40,10044900,9.40
2014-12-05,9.80,9.87,9.40,9.42,11870000,9.42
2014-12-04,9.91,9.96,9.80,9.87,11479100,9.87
2014-12-03,9.79,9.94,9.72,9.90,8020200,9.90
2014-12-02,9.69,9.85,9.69,9.80,4968100,9.80
2014-12-01,9.91,9.96,9.66,9.73,8361000,9.73
2014-11-28,10.00,10.00,9.75,9.91,10626900,9.91
2014-11-27,9.59,10.06,9.55,10.02,14217200,10.02
2014-11-26,9.68,9.68,9.51,9.57,5023800,9.57
2014-11-25,9.53,9.63,9.46,9.63,6489500,9.63
2014-11-24,9.52,9.59,9.45,9.51,6608200,9.51
2014-11-21,9.51,9.58,9.45,9.50,4262800,9.50
2014-11-20,9.48,9.57,9.41,9.48,3173800,9.48
2014-11-19,9.60,9.69,9.47,9.54,5638000,9.54
2014-11-18,9.47,9.68,9.44,9.60,9135000,9.60
2014-11-17,9.50,9.62,9.35,9.53,5859400,9.53
2014-11-14,9.46,9.52,9.34,9.41,4589000,9.41
2014-11-13,9.30,9.53,9.23,9.48,10812900,9.48
2014-11-12,9.00,9.30,8.91,9.29,5508900,9.29
"""

describe "trending calculator" do
  # it "should draw line for a stock" do
  #   stock = Stock.new("000635", "sz")
  #   end_date = Date.today
  #   begin_date = end_date - 6 * 30
  #   allow(YahooHistory).to receive(:fetch_data).and_return(HISTORY_STR)
  #   TrendingCalculator.calc_trending(stock)
  # end

  it "should skip if too many days is below the support line" do
    stock = Stock.new("600438")
    end_date = Date.today
    begin_date = end_date - 6 * 30
    allow(YahooHistory).to receive(:fetch_data).and_return(HISTORY_STR2)
    slines, plines = TrendingCalculator.calc_trending(stock)
    expect(slines).to be_nil
  end
end
