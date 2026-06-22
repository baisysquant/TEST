
SELECT  day_time,
	count(DISTINCT(disn)),
	sum(RATING_USAGE)/60/60,
	sum(ACTUAL_CHARGE)
FROM
	(
	SELECT
		DISTINCT PRI_IDENTITY AS disn,
		RATING_USAGE ,
		ACTUAL_CHARGE ,
		to_CHAR(START_DATE , 'yyyy-MM-dd') AS day_time
	FROM
		EF_CDR_4Q_202606
	WHERE
		STD_EVT_TYPE_ID = 11000
		AND START_DATE + 1 / 24 >= to_date('2026-06-01 00:00:00', 'yyyy-MM-dd HH24:mi:ss')
		AND START_DATE + 1 / 24 < to_date('2026-06-08 00:00:00', 'yyyy-MM-dd HH24:mi:ss') 
)
GROUP BY
	day_time ;
