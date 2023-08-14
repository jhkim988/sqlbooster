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
	

-- 데이터 집합과 데이터 집합의 연결 (where 절의 Filter 조건을 거친 결과끼리 연결)
-- 여러 테이블을 조인하더라도, 조인하는 순간에는 두 개씩 이루어진다.

-- 잘못 작성한 조인(M:1:M 조인)
-- 고객:아이템평가 1:M, 고객:주문 1:M 인 상황에서 세 개의 테이블을 조인
-- 특정 조건의 17년 3월의 아이템평가 기록과 3월 주문에 대해, 고객ID, 고객명별 아이템평가 건수, 주문건수 출력
SELECT 
	t1.CUS_ID 
	, t1.CUS_NM 
	, count(t2.ITM_ID) EVAL_CNT
	, count(t3.ORD_SEQ) ORD_CNT
FROM M_CUS t1, T_ITM_EVL t2, T_ORD t3
WHERE 
	t1.CUS_ID = t2.CUS_ID 
	AND t1.CUS_ID = t3.CUS_ID 
	AND t2.EVL_DT >= TO_DATE('20170301', 'YYYYMMDD')
	AND t2.EVL_DT < TO_DATE('20170401', 'YYYYMMDD')
	AND t3.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
	AND t3.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
GROUP BY t1.CUS_ID, t1.CUS_NM;

-- UNION ALL 을 사용하는 방법
SELECT
	t4.CUS_ID
	, MAX(t4.CUS_NM)
	, SUM(t4.EVAL_CNT)
	, SUM(t4.CUS_NM)
FROM (
	SELECT 
		t1.CUS_ID CUS_ID
		, t1.CUS_NM CUS_NM
		, count(t2.ITM_ID) EVAL_CNT
		, NULL ORD_CNT
	FROM M_CUS t1, T_ITM_EVL t2
	WHERE 
		t1.CUS_ID  = t2.CUS_ID 
		AND t2.EVL_DT >= TO_DATE('20170301', 'YYYYMMDD')
		AND t2.EVL_DT < TO_DATE('20170401', 'YYYYMMDD')
	GROUP BY t1.CUS_ID, t1.CUS_NM
	UNION ALL
	SELECT 
		t1.CUS_ID CUS_ID
		, t1.CUS_NM CUS_NM
		, NULL EVAL_CNT
		, count(t3.ORD_SEQ) ORD_CNT
	FROM M_CUS t1, T_ORD t3
	WHERE 
		t1.CUS_ID  = t3.CUS_ID 
		AND t3.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
		AND t3.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
	GROUP BY t1.CUS_ID, t1.CUS_NM
) t4
GROUP BY t4.CUS_ID;
-- M:1 을 먼저 1로 만든 후 나머지 조인을 하는 방법
-- 모두 1로 만든 후 1:1:1 조인을 하는 방법 
