select to_timestamp(td_store_ts), * from ssn_teledata
where 
td_account = 1 and
td_device = 1004 and td_channel = 3

order by td_store_ts desc
limit 200
