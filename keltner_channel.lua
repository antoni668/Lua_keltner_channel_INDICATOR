local math_floor = math.floor
local table_insert = table.insert
local math_abs = math.abs
local math_max = math.max

function dValue(index, v_type)
	v_type = v_type or "C"
	if v_type == "O" then --Open
		return O(index)
	elseif v_type == "H" then --High
		return H(index)
	elseif v_type == "L" then --Low
		return L(index)
	elseif v_type == "C" then --Close
		return C(index)
	elseif v_type == "V" then --Volume
		return V(index)
	elseif v_type == "M" then --Median
		return (H(index) + L(index))/2
	elseif v_type == "T" then --Typical
		return (H(index) + L(index)+C(index))/3
	elseif v_type == "W" then --Weighted
		return (H(index) + L(index)+2*C(index))/4
	else
		return C(index)
	end
end

Settings =
	{
		Name = "Keltner Channel",
		PeriodMA = 20,
		PeriodATR = 10,
		K = 2.0,
		value_type = "C",
		value_range = "ATR", --TR, R
		MA_type = "EMA", --SMA
		line= {
			{
				Name = "MA",
				Color = RGB(53, 47, 255),
				Type = TYPE_LINE,
				Width = 1
			},
			{
				Name = "MA+",
				Color = RGB(53, 47, 255),
				Type = TYPE_LINE,
				Width = 1
			},
			{
				Name = "MA-",
				Color = RGB(53, 47, 255),
				Type = TYPE_LINE,
				Width = 1
			}
		}
	}
function Init()
	return 3
end

function round(value)
	return math_floor(value / step + 0.5) * step
end

function TrHighest(index)
	local max_table = {}
	table_insert(max_table, math_abs(H(index)-L(index)))
	table_insert(max_table, math_abs(H(index)-C(index-1)))
	table_insert(max_table, math_abs(C(index-1)-L(index)))
	return math_max(unpack(max_table))
end

tr = {}
trMa = {}
cEma = {}
local per = 0

function average(_start, _end)
	local sum=0
	for i = _start, _end do
		sum=sum + tr[i]
	end
	return sum/(_end-_start+1)
end

function averageC(_start, _end)
	local sum=0
	local l0 = 0
	for i = _start, _end do
		l0 = dValue(i, Settings.value_type)
		sum=sum+l0
	end
	return sum/(_end-_start+1)
end

function trMA(ind, _p)
	local period = _p
	local index = ind
	if index <= period then
		trMa[index] = average(1,index)
		return trMa[index]
	end
	local n = (trMa[index-1]*(period-1) + tr[index])/period
	trMa[index] = n
	return n
end

function averageEMA(ind, _p)
	local n = 0
	local p = 0
	local period = _p
	local index = ind
	local k = 2/(period+1)
	local l0 = dValue(index, Settings.value_type)
	if index < period then
		cEma[index] = averageC(1,index)
		return cEma[index]
	end
	p = cEma[index-1] or l0
	n = k*l0+(1-k)*p
	cEma[index] = n
	return n
end

function isATR(index)
	if Settings.value_range == "TR" then
		return tr[index]
	elseif Settings.value_range == "R" then
		Settings.PeriodATR = Settings.PeriodMA
		return trMA(index, Settings.PeriodATR)
	else --"ATR"
		return trMA(index, Settings.PeriodATR)
	end
end

function OnCalculate(index)
	local _ma
	local _atr
	local delta
	local _low
	local _high
	if index == 1 then
		t=getDataSourceInfo()
		tr[index]=H(index)-L(index)
		step = getSecurityInfo(t.class_code, t.sec_code).min_price_step
		per = math.max(Settings.PeriodMA, Settings.PeriodATR)
	else
		tr[index]=TrHighest(index)
	end

	if Settings.MA_type == "SMA" then
		if index >= per then
			_ma = averageC(index-(Settings.PeriodMA-1), index)
			_ma = round(_ma)
		else
			return nil
		end
		_atr = isATR(index)
	else -- "EMA"
		_ma = averageEMA(index, Settings.PeriodMA)
		_ma = round(_ma)
		_atr = isATR(index)
		if index < per then
			return nil
		end
	end

	delta = round(_atr*Settings.K)
	_low = _ma-delta
	_high = _ma+delta
	return _ma, _high, _low
end
