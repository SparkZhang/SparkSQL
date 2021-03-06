#逾期率指标计算
add jar /home/etl_ket_azk/app/jar/HiveUDF-1.0-SNAPSHOT.jar;
create temporary function month_sub as 'com.guofei.month_sub';
create temporary function month_add as 'com.guofei.month_add';
use rmdb;
--T月的M2+及以上的剩余本息，含到期/T-2月末的合同本息（含到期、含结清）
INSERT OVERWRITE TABLE rpt_asset_qlty_chnl_totl partition(dt='2016-11-14',type=11)
--插入数据
select n1.chnl_code, --渠道码
11 as ind_type,
(coalesce(n2.rmd_interest,0)/n1.t2_0_remain_prin_int_total) as m2,
regexp_replace(substring(month_add(n1.bill_m,2), 1 ,7),'-','') as bill_mth, --月份
current_timestamp      as    etl_dt                     -- 批量日期
from
(
	select t2.chnl_code,t3.bill_m,
	sum(t3.contract_amt_interest) as t2_0_remain_prin_int_total -- T-2月末的合同本息（含到期的已结清）
	from
	(
		select contr_num,intpc_id
		from blm_contr_info  --放款合同信息表
		where dt='2016-11-14'
	)t1
	inner join
	(
		select intpc_id,chnl_code,presona_id,id_num    --身份证号
		from blb_intpc_info --进件表
		where dt='2016-11-14' and upper(substr(chnl_code,1,5))='306DC'
	)t2
	on t1.intpc_id=t2.intpc_id
	inner join
	(
		select  bill_m bill_m,contract_num,contract_amt_interest,cust_card_id --身份证号
		from agg_asset_debit_info
		where bill_m=month_sub('2016-10-01',2)
	)t3
	on t1.contr_num=t3.contract_num and t2.id_num=t3.cust_card_id
	group by t2.chnl_code,t3.bill_m

)n1
left join
(
	select b.chnl_code as chnl_code,--渠道编码
	sum(c.rmd_interest) as rmd_interest--剩余本息
	from
	(
		select
		contr_num,--合同号
		intpc_id  --进件号
		from blm_contr_info  --放款合同信息表
		where dt='2016-11-14'
	)a
	inner join
	(
		select intpc_id,chnl_code,presona_id,id_num    --身份证号
		from blb_intpc_info --进件表
		where dt='2016-11-14' and upper(substr(chnl_code,1,5))='306DC'
	)b
	on a.intpc_id=b.intpc_id
	inner join
	(
		select
		bill_m,       --账单月
		cust_card_id, --身份证号
		contract_num, --合同号
		total_over_periods, --总逾期期数
		(case when rmd_interest is null then 0 else rmd_interest end)rmd_interest --剩余本息
		from agg_asset_debit_info
		where bill_m='2016-10-01' and total_over_periods>=2 --and rmd_interest is not null
	)c
	on a.contr_num=c.contract_num and b.id_num=c.cust_card_id
	group by b.chnl_code

)n2
on n1.chnl_code=n2.chnl_code
