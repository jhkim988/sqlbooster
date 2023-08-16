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
	, count(DISTINCT t2.ITM_ID || '-' || TO_CHAR(t2.EVL_LST_NO)) EVAL_CNT -- 조인을 잘못 작성하여 뜬금없는 DISTINCT 를 사용한다.
	, count(DISTINCT t3.ORD_SEQ) ORD_CNT -- 조인을 잘못 작성하여 뜬금없는 DISTINCT 를 사용한다.
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
-- UNION ALL 을 수행할 대상이 많고 SELECT절에 사용하는 컬럼이 많으면 번거롭지만, 직관적이다.
SELECT
	t4.CUS_ID
	, MAX(t4.CUS_NM)
	, SUM(t4.EVAL_CNT)
	, SUM(t4.ORD_CNT)
FROM (
	SELECT 
		t1.CUS_ID CUS_ID
		, MAX(t1.CUS_NM) CUS_NM
		, count(*) EVAL_CNT
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
		, MAX(t1.CUS_NM) CUS_NM
		, NULL EVAL_CNT
		, count(*) ORD_CNT
	FROM M_CUS t1, T_ORD t3
	WHERE 
		t1.CUS_ID  = t3.CUS_ID 
		AND t3.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
		AND t3.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
	GROUP BY t1.CUS_ID, t1.CUS_NM
) t4
GROUP BY t4.CUS_ID
ORDER BY t4.CUS_ID;

-- M:1 을 먼저 1로 만든 후 나머지 조인을 하는 방법
-- UNION ALL + 인라인뷰, M_CUS JOIN 을 인라인뷰 바깥으로 옮겼다.
SELECT 
	t1.CUS_ID
	, MAX(t1.CUS_NM)
	, SUM(t4.EVAL_CNT)
	, SUM(t4.ORD_CNT)
FROM 
	M_CUS t1
	, (
	SELECT 
		t2.CUS_ID CUS_ID
		, COUNT(*) EVAL_CNT
		, NULL ORD_CNT
	FROM T_ITM_EVL t2
	WHERE 
		t2.EVL_DT >= TO_DATE('20170301', 'YYYYMMDD')
		AND t2.EVL_DT < TO_DATE('20170401', 'YYYYMMDD')
	GROUP BY t2.CUS_ID
	UNION ALL
	SELECT
		t3.CUS_ID CUS_ID
		, NULL EVAL_CNT 
		, COUNT(*) ORD_CNT
	FROM T_ORD t3
	WHERE 
		t3.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
		AND t3.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
	GROUP BY t3.CUS_ID
	) t4
WHERE t1.CUS_ID = t4.CUS_ID
GROUP BY t1.CUS_ID
ORDER BY t1.CUS_ID;

-- 모두 1로 만든 후 1:1:1 조인을 하는 방법
-- 주의할 점은, T_ITM_EVL, T_ORD 모두 있는 M_CUS 나오게 된다. 무조건 조인결과가나오게 하려면 outer join을 해야 한다.
SELECT 
	t1.CUS_ID,
	t2.EVL_CNT
	,t3.ORD_CNT
FROM
	M_CUS t1
	, (
	SELECT 
		t2.CUS_ID
		, COUNT(*) EVL_CNT
	FROM T_ITM_EVL t2
	WHERE 
		t2.EVL_DT >= TO_DATE('20170301', 'YYYYMMDD')
		AND t2.EVL_DT < TO_DATE('20170401', 'YYYYMMDD')
	GROUP BY t2.CUS_ID
	) t2,
	(
	SELECT	
		t3.CUS_ID
		, COUNT(*) ORD_CNT
	FROM T_ORD t3
	WHERE 
		t3.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
		AND t3.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
	GROUP BY t3.CUS_ID 
	) t3
WHERE
	t1.CUS_ID = t2.CUS_ID 
	AND t1.CUS_ID = t3.CUS_ID 
ORDER BY t1.CUS_ID;

-- Range-Join: 조인 조건으로 범위(like, <, >)나 != 를 설정하는 방
-- case 를 이용하여 가격유형별로 주문 건수를 카운트
SELECT 
	t1.ORD_ST 
	, CASE WHEN t1.ORD_AMT >= 5000 THEN 'High Order' 
		WHEN t1.ORD_AMT >= 3000 THEN 'Middle Order'
		ELSE 'Low Order' END ORD_AMT_TP
	, count(*) ORD_CNT
FROM T_ORD t1
GROUP BY t1.ORD_ST
	, CASE WHEN t1.ORD_AMT >= 5000 THEN 'High Order' 
		WHEN t1.ORD_AMT >= 3000 THEN 'Middle Order'
		ELSE 'Low Order' END
ORDER BY 1, 2;
-- 위와 같은 SQL 이 일회성이 아니라면, 주문금액유형 테이블을 만들어 조인으로 해결해야 한다.

-- 주문금액유형 테이블 생성
CREATE TABLE M_ORD_AMT_TP (
	ORD_AMT_TP VARCHAR2(40) NOT NULL,
	FR_AMT NUMBER(18, 3) NULL,
	TO_AMT NUMBER(18, 3) NULL
);
CREATE UNIQUE INDEX PK_M_ORD_AMT_TP ON M_ORD_AMT_TP(ORD_AMT_TP);
ALTER TABLE M_ORD_AMT_TP ADD CONSTRAINT PK_M_ORD_AMT_TP PRIMARY KEY (ORD_AMT_TP) USING INDEX;

-- 주문금액유형 데이터 생성
INSERT INTO M_ORD_AMT_TP(ORD_AMT_TP, FR_AMT, TO_AMT)
	SELECT 'Low Order', 0, 3000 FROM DUAL UNION ALL 
	SELECT 'Middle Order', 3000, 5000 FROM DUAL UNION ALL
	SELECT 'High Order', 5000, 999999999999 FROM DUAL;
COMMIT;

-- Range Join 을 이용하여 해결
SELECT
	t1.ORD_ST
	, t2.ORD_AMT_TP
	, count(*) ORD_CNT
FROM T_ORD t1, M_ORD_AMT_TP t2
WHERE
	NVL(t1.ORD_AMT, 0) >= t2.FR_AMT 
	AND NVL(t1.ORD_AMT,0) < t2.TO_AMT
GROUP BY t1.ORD_ST, t2.ORD_AMT_TP
ORDER BY 1, 2


-- Outer Join
-- 조인 조건을 만족하지 않은 데이터도 결과에 나온다.
-- 기준 데이터 집합: outer join 의 기준이 되는 집합, 조인조건을 만족하지 않아도 모두 결과에 포함된다. (단, 필터조건은 만족해야한다.)
-- 참조 데이터 집합: outer join 의 참조가 되는 집합, 조인조건에 (+)가 붙는다.
SELECT
	t1.CUS_ID 
	, t1.CUS_NM 
	, t2.CUS_ID 
	, t2.ITM_ID 
	, t2.EVL_LST_NO 
FROM M_CUS t1, T_ITM_EVL t2
WHERE
	t1.CUS_ID IN ('CUS_0002', 'CUS_0011')
	AND t1.CUS_ID = t2.CUS_ID(+)
ORDER BY t1.CUS_ID;
	
-- outer join 에서는 참조 데이터 집합의 필터조건에도 (+) 표시를 추가해야한다.
-- 참조 쪽 필터조건에 (+) 사용: outer join 전에 필터조건이 사용된다.
-- 참조 쪽 필터조건에 (+) 미사용: outer join 후, 조인 결과에 필터조건이 사용된다.
-- (+) 를 제외해야 원하는 결과가 나온다면, inner join 을 수행하면 되므로, 보통은 (+) 조건을 사용한다.
SELECT
	t1.CUS_ID 
	, t1.CUS_NM 
	, t2.CUS_ID 
	, t2.ITM_ID 
	, t2.EVL_LST_NO 
FROM M_CUS t1, T_ITM_EVL t2
WHERE
	t1.CUS_ID IN ('CUS_0073')
	AND t1.CUS_ID = t2.CUS_ID (+)
	AND t2.EVL_DT(+) >= TO_DATE('20170201', 'YYYYMMDD') -- (+) 를 넣지 않으면, OUTER JOIN 후에 필터를 적용하는데, NULL 값이므로 조건을 만족할 수 없어 데이터가 나오지 않게 된다.
	AND t2.EVL_DT(+) < TO_DATE('20170301', 'YYYYMMDD')

-- 실행이 불가능한 outer join
-- (+) 가 표시된 참조데이터 집합은 두 개 이상의 기준 데이터 집합을 동시에 가질 수 없다. (11g 기준)
SELECT
	t1.CUS_ID 
	,t2.ITM_ID 
	,t1.ORD_DT 
	,t3.ITM_ID
	,t3.EVL_PT
FROM
	T_ORD t1
	, T_ORD_DET t2
	, T_ITM_EVL t3
WHERE 
	t1.ORD_SEQ = t2.ORD_SEQ 
	AND t1.CUS_ID = 'CUS_0002'
	AND t1.ORD_DT >= TO_DATE('20170122', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20170123', 'YYYYMMDD')
	AND t3.CUS_ID(+) = t1.CUS_ID 
	AND t3.ITM_ID(+) = t2.ITM_ID;

-- 인라인뷰를 이용하여 해결하는 방법 (t1, t2 의 조인을 인라인뷰로 처리하여 하나의 데이터 집합을 기준 데이터 집합으로 삼는다.)
SELECT
	t4.CUS_ID 
	,t4.ITM_ID 
	,t4.ORD_DT 
	,t3.ITM_ID
	,t3.EVL_PT
FROM
	T_ITM_EVL t3, (
	SELECT 
		t1.CUS_ID CUS_ID 
		, t2.ITM_ID ITM_ID
		, t1.ORD_DT ORD_DT
	FROM T_ORD t1, T_ORD_DET t2
	WHERE
		t1.ORD_SEQ = t2.ORD_SEQ 
		AND t1.CUS_ID = 'CUS_0002'
		AND t1.ORD_DT >= TO_DATE('20170122', 'YYYYMMDD')
		AND t1.ORD_DT < TO_DATE('20170123', 'YYYYMMDD')
) t4
WHERE 
	t3.CUS_ID(+) = t4.CUS_ID
	AND t3.ITM_ID(+) = t4.ITM_ID;
	
-- ANSI 표준을 사용하는 방법.
-- 다른 DBMS 로 마이그레이션을 고려하면 ANSI 표준으로 SQL 을 개발해도 좋다. 그러나 Oracle 에서 성능을 위한 힌트가 잘 적용되지 않을 수 있다.
SELECT
	t1.CUS_ID 
	,t2.ITM_ID 
	,t1.ORD_DT 
	,t3.ITM_ID
	,t3.EVL_PT
FROM
	T_ORD t1
	INNER JOIN T_ORD_DET t2 ON (
		t1.ORD_SEQ = t2.ORD_SEQ
		AND t1.ORD_DT >= TO_DATE('20170122', 'YYYYMMDD')
		AND t1.ORD_DT < TO_DATE('20170123', 'YYYYMMDD')
	)
	LEFT OUTER JOIN T_ITM_EVL t3 ON (
		t3.CUS_ID = t1.CUS_ID 
		AND t3.ITM_ID = t2.ITM_ID 
	)
WHERE t1.CUS_ID = 'CUS_0002';

-- outer join 과 inner join 을 동시에 사용할 때 주의할 점
-- t1 과 t2 가 outer join 을 한다. 이 때 CUS_0073 의 T_ORD 데이터가 없으므로 null 이 나온다.
-- 위의 데이터 결과 집합에서 T_ORD_DET 와 inner join 한다. 위에서 ORD_SEQ 가 null 이므로 inner join 결과는 나오지 않는다.
SELECT 
	t1.CUS_ID
	, t2.ORD_SEQ 
	, t2.ORD_DT 
	, t3.ORD_SEQ 
	, t3.ITM_ID 
FROM M_CUS t1, T_ORD t2, T_ORD_DET t3
WHERE
	t1.CUS_ID = 'CUS_0073'
	AND t1.CUS_ID = t2.CUS_ID(+)
	AND t2.ORD_DT(+) >= TO_DATE('20170122', 'YYYYMMDD')
	AND t2.ORD_DT(+) < TO_Date('20170123', 'YYYYMMDD')
	AND t3.ORD_SEQ(+) = t2.ORD_SEQ; -- OUTER JOIN 으로 변경해야 데이터가 제대로 나온다.
	
-- 고객ID 별 주문건수, 주문이 없는고객도 나오도록 처리
-- 주의할 점은 count(*) 은 null 값도 카운트하기 때문에 count(t2.ORD_SEQ) 로 수행해야한다.
SELECT 
	t1.CUS_ID 
	, COUNT(*) ORD_CNT_1
	, COUNT(t2.ORD_SEQ) ORD_CNT_2 
FROM M_CUS t1, T_ORD t2
WHERE
	t1.CUS_ID = t2.CUS_ID(+)
	AND t2.ORD_DT(+) >= TO_DATE('20170101', 'YYYYMMDD')
	AND t2.ORD_DT(+) < TO_DATE('20170201', 'YYYYMMDD') 
GROUP BY t1.CUS_ID
ORDER BY t1.CUS_ID;

-- 아이템별 특정 월의 주문건수
-- M_ITM, T_ORD(주문날짜, 주문상태), T_ORD_DET(수량)
SELECT 
	t1.ITM_ID 
	, t1.ITM_NM 
	, NVL(t4.ORD_QTY, 0)
FROM
	M_ITM t1
	, (
	SELECT 
		t3.ITM_ID
		, SUM(t3.ORD_QTY) ORD_QTY
	FROM T_ORD t2, T_ORD_DET t3
	WHERE
		t2.ORD_SEQ = t3.ORD_SEQ 
		AND t2.ORD_ST = 'COMP'
		AND t2.ORD_DT >= TO_DATE('20170101', 'YYYYMMDD')
		AND t2.ORD_DT < TO_DATE('20170201', 'YYYYMMDD')
	GROUP BY t3.ITM_ID 
	) t4
WHERE
	t1.ITM_ID = t4.ITM_ID(+)
	AND t1.ITM_TP IN ('PC', 'ELEC');
	

-- Cartesian Join: 조인조건이 없는 조인, 모든 조합을 만들어낸다.
-- 주로 분석차원집합을 만들거나, 테스트 데이터를 만들기 위해 일회성으로 사용한다.
SELECT
	t1.CUS_GD, t2.ITM_TP
FROM (
	SELECT DISTINCT A.CUS_GD FROM M_CUS A
) t1, (
	SELECT DISTINCT A.ITM_TP FROM M_ITM A
) t2

-- 특정 고객의 2, 3, 4 월의 실적을 조회하는 SQL
SELECT 
	t1.CUS_ID 
	, t1.CUS_NM
	, t2.ORD_YM
	, t2.ORD_CNT
FROM
	M_CUS t1
	, (
	SELECT
		A.CUS_ID
		, TO_CHAR(A.ORD_DT, 'YYYYMM') ORD_YM
		, COUNT(*) ORD_CNT
	FROM T_ORD A
	WHERE
		A.CUS_ID IN ('CUS_0003', 'CUS_0004')
		AND A.ORD_DT >= TO_DATE('20170201', 'YYYYMMDD')
		AND A.ORD_DT < TO_DATE('20170501', 'YYYYMMDD')
	GROUP BY A.CUS_ID, TO_CHAR(A.ORD_DT, 'YYYYMM')
	) t2
WHERE
	t1.CUS_ID IN ('CUS_0003', 'CUS_0004')
	AND t1.CUS_ID = t2.CUS_ID(+)
ORDER BY t1.CUS_ID, t2.ORD_YM;

-- 실적 없는 달을 0건으로 나오게 하려면
SELECT 
	t0.CUS_ID
	, t0.CUS_NM
	, t0.BASE_YM
	, NVL(t2.ORD_CNT, 0)
FROM (
	SELECT
		t1.CUS_ID 
		, t1.CUS_NM 
		, t4.BASE_YM
	FROM
		M_CUS t1
		, (
		SELECT TO_CHAR(ADD_MONTHS(TO_DATE('20170201', 'YYYYMMDD'), ROWNUM-1), 'YYYYMM') BASE_YM
		FROM dual
		CONNECT BY ROWNUM <= 3
		) t4
	WHERE t1.CUS_ID IN ('CUS_0003', 'CUS_0004')
) t0, (
	SELECT
		A.CUS_ID
		, TO_CHAR(A.ORD_DT, 'YYYYMM') ORD_YM
		, COUNT(*) ORD_CNT
	FROM T_ORD A
	WHERE
		A.CUS_ID IN ('CUS_0003', 'CUS_0004')
		AND A.ORD_DT >= TO_DATE('20170201', 'YYYYMMDD')
		AND A.ORD_DT < TO_DATE('20170501', 'YYYYMMDD')
	GROUP BY A.CUS_ID, TO_CHAR(A.ORD_DT, 'YYYYMM')
	) t2
WHERE
	t0.CUS_ID = t2.CUS_ID(+)
	AND t0.BASE_YM = t2.ORD_YM(+)
ORDER BY T0.CUS_ID, T0.BASE_YM;

-- 고객등급, 아이템 유형별 주문수량
SELECT 
	cus.CUS_GD
	, itm.ITM_TP 
	, SUM(det.ORD_QTY)
FROM 
	M_CUS cus
	, M_ITM itm
	, T_ORD ord
	, T_ORD_DET det
WHERE
	cus.CUS_ID = ord.CUS_ID 
	AND ord.ORD_SEQ = det.ORD_SEQ 
	AND det.ITM_ID = itm.ITM_ID 
	AND ord.ORD_ST = 'COMP'
GROUP BY cus.CUS_GD, itm.ITM_TP
ORDER BY cus.CUS_GD, itm.ITM_TP;

-- 주문이 없는 아이템 유형도 나오게 하고 싶다면
SELECT 
	t1.CUS_GD
	, t1.ITM_TP
	, NVL(t0.QTY_CNT, 0)
FROM 
	(
	SELECT 
		cus.CUS_GD
		, itm.ITM_TP 
		, SUM(det.ORD_QTY) QTY_CNT
	FROM 
		M_CUS cus
		, M_ITM itm
		, T_ORD ord
		, T_ORD_DET det
	WHERE
		cus.CUS_ID = ord.CUS_ID 
		AND ord.ORD_SEQ = det.ORD_SEQ 
		AND det.ITM_ID = itm.ITM_ID 
		AND ord.ORD_ST = 'COMP'
	GROUP BY cus.CUS_GD, itm.ITM_TP
	) t0, (
		SELECT CUS_GD, ITM_TP
		FROM (
			SELECT DISTINCT cus.CUS_GD FROM M_CUS cus		
		), (
			SELECT DISTINCT itm.ITM_TP FROM M_ITM itm		
		)
	) t1
WHERE
	t0.CUS_GD(+) = t1.CUS_GD	
	AND t0.ITM_TP(+) = t1.ITM_TP
ORDER BY t1.CUS_GD, t1.ITM_TP;

-- 테스트 데이터 만들기
SELECT
	rownum ORD_NO
	, t1.CUS_ID
	, t2.ORD_ST
	, t3.PAY_TP
	, t4.ORD_DT
FROM
	M_CUS t1
	, (
		SELECT 'WAIT' ORD_ST FROM DUAL UNION ALL 
		SELECT 'COMP' ORD_ST FROM DUAL
	) t2, (
		SELECT 'CARD' PAY_TP FROM DUAL UNION ALL
		SELECT 'BANK' PAY_TP FROM DUAL UNION ALL
		SELECT NULL PAY_TP FROM DUAL
	) t3, (
		SELECT TO_DATE('20170101', 'YYYYMMDD') + (ROWNUM-1) ORD_DT FROM DUAL CONNECT BY ROWNUM <= 365
	) t4;
-- 분포도 조정: WAIT 과 COMP 의 비율을 2:3으로 하고 싶다면
SELECT 'WAIT' ORD_ST FROM DUAL CONNECT BY ROWNUM <= 2 UNION ALL 
SELECT 'COMP' ORD_ST FROM DUAL CONNECT BY ROWNUM <= 3;