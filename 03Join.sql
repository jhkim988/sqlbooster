-- Inner Join
-- Where 절에서 Filter 조건과 Join 조건
-- Filter 조건: From 절의 테이블에서 필요한 데이터를 걸러낸다.
-- Join 조건: 두 개의 테이블을 연결하는 역할을 한다.
-- 1. Join 조건을 만족하는 데이터만 결합되어 결과에 나온다. (등호 말고 다른 조건 가능)
-- 2. 한 건과 M 건이 join 되면 M 건이 나온다. 
SELECT
	t1.col1
	, t2.col1
FROM (
	SELECT 'A' col1 FROM dual
	UNION ALL
	SELECT 'B' col1 FROM dual
	UNION ALL
	SELECT 'C' col1 FROM DUAL 
) t1, (
	SELECT 'A' col1 FROM DUAL 
	UNION ALL
	SELECT 'B' col1 FROM dual
	UNION ALL
	SELECT 'B' col1 FROM dual
	UNION ALL
	SELECT 'D' col1 FROM dual
) t2
WHERE t1.col1 = t2.col1;

-- join 테이블이나 조건의 순서가 바뀌어도, 성능에는 영향이 있을 수 있지만 결과에는 영향을 끼치지 않는다.
SELECT 
	t1.CUS_ID 
	, t1.CUS_GD
	, t2.ORD_SEQ 
	, t2.CUS_ID 
	, t2.ORD_DT 
FROM M_CUS t1, T_ORD t2
WHERE
	t1.CUS_ID = t2.CUS_ID 
	AND t1.CUS_GD = 'A'
	AND t2.ORD_DT >= TO_DATE('20170101', 'YYYYMMDD')
	AND t2.ORD_DT < TO_DATE('20170201', 'YYYYMMDD');
	

-- 데이터 집합과 데이터 집합의 연