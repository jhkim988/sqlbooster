----------------------------------------------------------------------------------------------------
-- 실행계획 출력
----------------------------------------------------------------------------------------------------
ALTER SYSTEM FLUSH BUFFER_CACHE; -- 정확한 테스트를 위해 버퍼캐시 삭제. 운영환경에서 절대 사용하면 안된다.

SELECT
	t.SQL_ID 
	, t.CHILD_NUMBER 
	, t.SQL_TEXT 
FROM V$SQL t
WHERE t.SQL_TEXT LIKE '%GATHER_PLAN_STATISTICS %'
ORDER BY t.LAST_ACTIVE_TIME DESC;

SELECT 
	*
FROM TABLE(dbms_xplan.display_cursor('8a8k1vz98fkm9', 0, 'ALLSTATS LAST'));
----------------------------------------------------------------------------------------------------