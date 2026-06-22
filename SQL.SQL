select count(disn),  sum(RATING_USAGE), sum(ACTUAL_CHARGE) from 

(SELECT  distinct PRI_IDENTITY as disn,    RATING_USAGE ,  ACTUAL_CHARGE ,   to_date(START_DATE ,'yyyy-MM-dd') as  day_time  FROM EF_CDR_4Q_202606 WHERE STD_EVT_TYPE_ID  = 11000   AND START_DATE  +1/24 >= to_date('2022-06-15 00:00:00','yyyy-MM-dd HH24:mi:ss') AND START_DATE  +1/24 < to_date('2022-06-21 00:00:00','yyyy-MM-dd HH24:mi:ss') 
) 
group by  day_time ;
select count(disn),  sum(RATING_USAGE), sum(ACTUAL_CHARGE) from 

(SELECT  distinct PRI_IDENTITY as disn,    RATING_USAGE ,  ACTUAL_CHARGE ,   to_date(START_DATE ,'yyyy-MM-dd') as  day_time  FROM EF_CDR_4Q_202606 WHERE STD_EVT_TYPE_ID  = 11006   AND START_DATE  +1/24 >= to_date('2022-06-15 00:00:00','yyyy-MM-dd HH24:mi:ss') AND START_DATE  +1/24 < to_date('2022-06-21 00:00:00','yyyy-MM-dd HH24:mi:ss') 
) 
group by  day_time ;
