最新价获取的方式改下，不再使用akshare，直接使用AShareHub， 传入参数中不需要指定具体代码， 直接获取全量的，接口介绍如下：

日线行情
A 股每日 OHLCV 价格数据。

GET /v1/market/daily
请求参数
参数	类型	必填	说明
ts_code	string	否	股票代码，如 000001.SZ
start_date	string	否	开始日期（YYYY-MM-DD）
end_date	string	否	结束日期（YYYY-MM-DD）
limit	int	否	最大行数（默认 100，最大 5000）
offset	int	否	分页偏移量（默认 0）
返回字段
字段	类型	说明
ts_code	string	股票代码
trade_date	string	交易日期
open / high / low / close	number	开盘价 / 最高价 / 最低价 / 收盘价
pre_close	number	昨收价
change / pct_chg	number	涨跌额 / 涨跌幅（%）
vol	number	成交量（手）
amount	number	成交额（千元）
