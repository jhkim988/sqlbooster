----------------------------------------------------------------------------------------------------
-- Join 의 내부처리 방식
----------------------------------------------------------------------------------------------------
-- NL JOIN: 중첩 반복문 형태로 데이터 연결하는 방식, 선행집합의 건 수만큼 후행집합을 반복 접근한다.
-- 선행 집합과 후행집합의 정의가 매우 중요하다.

-- Leading 은 테이블에 접근하는 순서를 지정한다.
-- USE_NL 은 NL JOIN 하게 한다.
SELECT
	/*+ GATHER_PLAN_STATISTICS LEADING(t1) USE_NL(t2) */
	t1.RGN_ID 
	, t1.CUS_ID 
	, t1.CUS_NM 
	, t2.ORD_DT 
	, t2.ORD_ST 
	, t2.ORD_AMT 
FROM M_CUS t1, T_ORD t2
WHERE t1.CUS_ID  = t2. CUS_ID;

-- MERGE JOIN: 두 데이터 집합을 연결 조건 값으로 정렬한 후 조인을 처리하는 방식, 연결 조건 기준으로 정렬돼 있어야 조인이 가능하다.
-- 실행계획 결과:
-- M_CUS: Index Full Scan, 리프 블록을 처음부터 끝까지 읽는 작업으로, 리프 블록들은 인덱스 키값으로 정렬돼 있기 때문에 CUS_ID 로 정렬한 것을 읽는 것과 같다.
-- T_ORD: SORT JOIN 오퍼레이션. SORT JOIN 은 자식 단계의 결과를 조인하기 위해 정렬하는 작업이다.
-- MERGE JOIN 은 소트 작업을 어떻게 줄이느갸가 성능 향상의 주요 포인트이다.
SELECT
	/*+ GATHER_PLAN_STATISTICS LEADING(t1) USE_MERGE(t2) */
	t1.RGN_ID 
	, t1.CUS_ID 
	, t1.CUS_NM 
	, t2.ORD_DT 
	, t2.ORD_ST 
	, t2.ORD_AMT 
FROM M_CUS t1, T_ORD t2
WHERE t1.CUS_ID  = t2. CUS_ID;

-- HASH JOIN: 해시함수를 이용한 처리 방식, 대용량 데이터를 조인할 때 적합하다.
-- 많은 조인 성능 문제가 HASH JOIN 으로 해결되지만, 다른 방식보다 CPU와 메모리 자원을 더 많이 사용한다.
-- 특히, OLTP 시스템에서 자주 사용되는 핵심 SQL 은 NL JOIN으로 처리되도록 해야한다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS LEADING(t1) USE_HASH(t2) */
	t1.RGN_ID 
	, t1.CUS_ID 
	, t1.CUS_NM 
	, t2.ORD_DT 
	, t2.ORD_ST 
	, t2.ORD_AMT 
FROM M_CUS t1, T_ORD t2
WHERE t1.CUS_ID = t2.CUS_ID ;
-- HASH JOIN 수행 순서:
-- 1. 선행집합(M_CUS) 를 FULL SCAN 하면서, 조인조건 컬럼값에 해시함수를 적용한다.
-- 2. 해시함수 결과값에 따라 데이터를 분류해 해시 영역에 올린다.
-- 3. 후행집합(T_ORD) 를 FULL SCAN 하면서, 조인조건 컬럼값에 해시 함수를 적용한다.
-- 4. 해시함수 결과값에 따라 해시영역에 있는 데이터와 조인을 수행한다.

-- NL JOIN 처럼 후행집합을 여러 번 반복접근하거나, MERGE JOIN 처럼 정렬을 하는 비효율이 없는 장점이 있다.
-- 그러나 고비용의 해시함수와 메모리의 일부인 해시영역을 사용하는 비용이 추가된다.


----------------------------------------------------------------------------------------------------
-- NL JOIN 과 성능
----------------------------------------------------------------------------------------------------
-- 테스트용 테이블: T_ORD_JOIN 
CREATE TABLE T_ORD_JOIN AS 
SELECT
	ROW_NUMBER() OVER (ORDER BY t1.ORD_SEQ, t2.ORD_DET_NO, t3.RNO) ORD_SEQ 
	, t1.CUS_ID 
	, t1.ORD_DT 
	, t1.ORD_ST
	, t1.PAY_TP 
	, t2.ITM_ID 
	, t2.ORD_QTY 
	, t2.UNT_PRC 
	, TO_CHAR(t1.ORD_DT, 'YYYYMMDD') ORD_YMD
FROM 
	T_ORD t1
	, T_ORD_DET t2
	, (SELECT ROWNUM RNO FROM dual CONNECT BY rownum <= 1000) t3
WHERE
 	t1.ORD_SEQ = t2.ORD_SEQ;
 
ALTER TABLE T_ORD_JOIN ADD CONSTRAINT pk_t_ord_join PRIMARY key(ord_seq) using INDEX;

EXEC DBMS_STATS.GATHER_TABLE_STATS('ORA_SQL_TEST', 'T_ORD_JOIN');

-- NL 조인은 후행 집합의 테이블 쪽의 조인조건컬럼에 인덱스가 필수다.
SELECT
	/*+ GATHER_PLAN_STATISTICS LEADING(t1) USE_NL(t2) INDEX(t2 X_T_ORD_JOIN_2) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_QTY * t2.UNT_PRC) ORD_AMT
FROM
	M_CUS t1
	, T_ORD_JOIN t2
WHERE
	t1.CUS_ID = t2.CUS_ID
	AND t1.CUS_ID = 'CUS_0009'
	AND t2.ORD_YMD = '20170218' -- 복합인덱스로 ORD_YMD 까지 설정하면 더 효율적이다.
GROUP BY t1.CUS_ID;

CREATE INDEX X_T_ORD_JOIN_1 ON T_ORD_JOIN(CUS_ID);
CREATE INDEX X_T_ORD_JOIN_2 ON T_ORD_JOIN(CUS_ID, ORD_YMD);

-- 선행집합 변경에 따른 쿼리 변형
SELECT
	/*+ GATHER_PLAN_STATISTICS LEADING(t2) USE_NL(t1) INDEX(t2 X_T_ORD_JOIN_2) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_QTY * t2.UNT_PRC) ORD_AMT
FROM
	M_CUS t1
	, T_ORD_JOIN t2
WHERE
	t1.CUS_ID = t2.CUS_ID
	AND t1.CUS_ID = 'CUS_0009'
	AND t2.ORD_YMD = '20170218'
--	AND t2.CUS_ID = 'CUS_0009' -- 옵티마이저가 자동으로 추가해준 조건. 실행계획에 Predicate Information 에서 확인할 수 있다.
GROUP BY t1.CUS_ID;
-- 이와 같이 옵티마이저가 자동으로 SQL 을 변형하는 기능을 쿼리 변형이라고 한다.
-- SQL 이 길고 복잡해지면 옵티마이져가 쿼리 변형을 제대로 수행하지 못하거나, 비효율적으로 쿼리변형을 할 때도 있다. 직접 추가/변경해야 한다.


-- 조인 횟수 줄이기#1: NL 조인에서 선행집합의 건 수를 줄이면 후행집합의 접근 횟수가 줄어든다.
-- 실행계획에서 두 번의 NL Loops 는 오라클 버전이 올라가면서 NL Join 성능을 높이려는 방법이다.
-- CUS_ID 에 대한 조건이 없기 때문에. 인덱스의 두 번째 조건을 이용하는 Index Skip Scan 이 일어난다. (많은 경우 Index Range Scan 이 더 좋다.)
-- 12,000 번의 후행집합 접근이 일어난다. 따라서 M_CUS 에 Index Range Scan 이 12,000 번 일어난다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS LEADING(t2) USE_NL(t1) INDEX(t2 X_T_ORD_JOIN_2) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_QTY * t2.UNT_PRC) ORD_AMT
FROM 
	M_CUS t1
	, T_ORD_JOIN t2
WHERE
	t1.CUS_ID = t2.CUS_ID
	AND t1.CUS_GD = 'A'
	AND t2.ORD_YMD = '20170218'
GROUP BY t1.CUS_ID;

-- 선행집합으로 M_CUS 를 선택하는 편이 좋다.
SELECT count(*) FROM M_CUS t1 WHERE t1.CUS_GD = 'A'; -- 60건
SELECT count(*) FROM T_ORD_JOIN t2 WHERE t2.ORD_YMD = '20170218'; -- 12,000건

SELECT 
	/*+ GATHER_PLAN_STATISTICS LEADING(t1) USE_NL(t2) INDEX(t2 X_T_ORD_JOIN_2) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_QTY * t2.UNT_PRC) ORD_AMT
FROM 
	M_CUS t1
	, T_ORD_JOIN t2
WHERE
	t1.CUS_ID = t2.CUS_ID
	AND t1.CUS_GD = 'A'
	AND t2.ORD_YMD = '20170218'
GROUP BY t1.CUS_ID;


-- 조인 횟수 줄이기#2: Like 조건이 있는 SQL
CREATE INDEX X_T_ORD_JOIN_3 ON T_ORD_JOIN(ORD_YMD);
SELECT 
	/*+ GATHER_PLAN_STATISTICS LEADING(t1) USE_NL(t2) INDEX(t2 X_T_ORD_JOIN_2) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_QTY * t2.UNT_PRC) ORD_AMT
FROM
	M_CUS t1
	, T_ORD_JOIN t2
WHERE
	t1.CUS_ID = t2.CUS_ID
	AND t2.ORD_YMD LIKE '201702%'
GROUP BY t1.CUS_ID;

-- 선행집합으로 M_CUS 를 사용하는 편이 좋다.
SELECT count(*) FROM M_CUS t1; -- 90 건 
SELECT count(*) FROM T_ORD_JOIN t2 WHERE t2.ORD_YMD LIKE '201702%'; -- 209k 건

-- 여러 테이블의 조인
-- 실행계획: HASH(M_ITM, NL(M_CUS, T_ORD_JOIN))
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	t1.ITM_ID 
	, t1.ITM_NM
	, t2.ORD_ST
	, count(*) ORD_QTY
FROM
	M_ITM t1
	, T_ORD_JOIN t2
	, M_CUS t3
WHERE
	t1.ITM_ID = t2.ITM_ID
	AND t2.CUS_ID = t3.CUS_ID 
	AND t1.ITM_TP = 'ELEC'
	AND t3.CUS_GD = 'B'
	AND t2.ORD_YMD LIKE '201702%'
GROUP BY t1.ITM_ID, t1.ITM_NM, t2.ORD_ST;

SELECT count(*) FROM M_CUS t3 WHERE t3.CUS_GD = 'B'; -- 30건 
SELECT count(*) FROM M_ITM t1 WHERE t1.ITM_TP = 'ELEC'; -- 10건 

-- 70,000 건
SELECT
	count(*)
FROM
	M_CUS t3
	, T_ORD_JOIN t2
WHERE
	t2.CUS_ID = t3.CUS_ID 
	AND t3.CUS_GD = 'B'
	AND t2.ORD_YMD LIKE '201702%';

-- 26,000 건, 먼저 NL JOIN 하는 게 유리하다.
-- M_ITM 이 10 건이므로 선행집합으로 설정한다.
-- T_ORD_JOIN 을 후행집합으로 사용하므로, ITM_ID 와 ORD_YMD 인덱스를 만든다.
SELECT 
	count(*)
FROM
	M_ITM t1
	, T_ORD_JOIN t2
WHERE
	t1.ITM_ID = t2.ITM_ID
	AND ITM_TP = 'ELEC'
	AND t2.ORD_YMD LIKE '201702%';
	
CREATE INDEX X_T_ORD_JOIN_4 ON T_ORD_JOIN(ITM_ID, ORD_YMD);

SELECT 
	/*+ GATHER_PLAN_STATISTICS USE_NL(t2) INDEX(t2 X_T_ORD_JOIN_4) */
	t1.ITM_ID 
	, t1.ITM_NM
	, t2.ORD_ST
	, count(*) ORD_QTY
FROM
	M_ITM t1
	, T_ORD_JOIN t2
	, M_CUS t3
WHERE
	t1.ITM_ID = t2.ITM_ID
	AND t2.CUS_ID = t3.CUS_ID 
	AND t1.ITM_TP = 'ELEC'
	AND t3.CUS_GD = 'B'
	AND t2.ORD_YMD LIKE '201702%'
GROUP BY t1.ITM_ID, t1.ITM_NM, t2.ORD_ST;


-- 과도한 성능 개선
-- Table Access Full 제거:
-- M_CUS: 인덱스 생성 (CUS_GD, CUS_ID)
-- M_ITM: 인덱스 생성 (ITM_TP, ITM_ID, ITM_NM) (ITM_NM 은 group by 에서 접근하므로 인덱스에 추가함)
CREATE INDEX X_M_CUS_1 ON M_CUS(CUS_GD, CUS_ID);
CREATE INDEX X_M_ITM_1 ON M_ITM(ITM_TP, ITM_ID, ITM_NM);
-- Full Scan 은 없앴지만, IO 는 4 밖에 줄지 않았다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(t1 X_M_ITM_1) INDEX(t2 X_T_ORD_JOIN_4) INDEX(t3 X_M_CUS_1) */
	t1.ITM_ID 
	, t1.ITM_NM
	, t2.ORD_ST
	, count(*) ORD_QTY
FROM
	M_ITM t1
	, T_ORD_JOIN t2
	, M_CUS t3
WHERE
	t1.ITM_ID = t2.ITM_ID
	AND t2.CUS_ID = t3.CUS_ID 
	AND t1.ITM_TP = 'ELEC'
	AND t3.CUS_GD = 'B'
	AND t2.ORD_YMD LIKE '201702%'
GROUP BY t1.ITM_ID, t1.ITM_NM, t2.ORD_ST;

-- Table Access By Index RowID 제거: 커버링 인덱스, t2.ORD_ST 도 추가한다.
CREATE INDEX X_T_ORD_JOIN_5 ON T_ORD_JOIN(ITM_ID, ORD_YMD, CUS_ID, ORD_ST);
-- 과도한 튜닝. 인덱스가 너무 많아지게 돼서 시스템 전반적인 문제가 생길 수 있다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(t1 X_M_ITM_1) INDEX(t2 X_T_ORD_JOIN_5) INDEX(t3 X_M_CUS_1) */
	t1.ITM_ID 
	, t1.ITM_NM
	, t2.ORD_ST
	, count(*) ORD_QTY
FROM
	M_ITM t1
	, T_ORD_JOIN t2
	, M_CUS t3
WHERE
	t1.ITM_ID = t2.ITM_ID
	AND t2.CUS_ID = t3.CUS_ID 
	AND t1.ITM_TP = 'ELEC'
	AND t3.CUS_GD = 'B'
	AND t2.ORD_YMD LIKE '201702%'
GROUP BY t1.ITM_ID, t1.ITM_NM, t2.ORD_ST;

DROP INDEX X_M_ITM_1;
DROP INDEX X_M_CUS_1;
DROP INDEX X_T_ORD_JOIN_5;


-- 선행 집합은 항상 작은 쪽이어야 하는가?
SELECT 
	/*+ GATHER_PLAN_STATISTICS LEADING(t1 t2) USE_NL(t2) INDEX(t2 X_T_ORD_BIG_4) */
	t1.CUS_ID
	, t1.CUS_NM
	, sum(t2.ORD_AMT)
FROM
	M_CUS t1
	, T_ORD_BIG t2
WHERE
	t1.CUS_ID = t2.CUS_ID 
	AND t2.ORD_YMD LIKE '201701%'
GROUP BY t1.CUS_ID, t1.CUS_NM
ORDER BY SUM(t2.ORD_AMT) DESC;

SELECT 
	/*+ GATHER_PLAN_STATISTICS LEADING(t2) USE_NL(t1) FULL(t2) */
	t1.CUS_ID
	, t1.CUS_NM
	, sum(t2.ORD_AMT)
FROM
	M_CUS t1
	, T_ORD_BIG t2
WHERE
	t1.CUS_ID = t2.CUS_ID 
	AND t2.ORD_YMD LIKE '201701%'
GROUP BY t1.CUS_ID, t1.CUS_NM
ORDER BY SUM(t2.ORD_AMT) DESC;


----------------------------------------------------------------------------------------------------
-- MERGE 조인과 성능
----------------------------------------------------------------------------------------------------
-- MERGE JOIN 은 대량의 데이터를 조인할 때 적합하다.
SELECT
	/*+ GATHER_PLAN_STATISTICS LEADING(t2) USE_NL(t1) FULL(t2) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_AMT) ORD_AMT
	, SUM(SUM(t2.ORD_AMT)) OVER() TTL_ORD_AMT
FROM
	M_CUS t1
	, T_ORD_BIG t2
WHERE
	t1.CUS_ID = t2.CUS_ID 
	AND t2.ORD_YMD LIKE '201702%'
GROUP BY t1.CUS_ID;

-- Merge 조인으로 변경
SELECT
	/*+ GATHER_PLAN_STATISTICS LEADING(t1) USE_MERGE(t2) FULL(t2) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_AMT) ORD_AMT
	, SUM(SUM(t2.ORD_AMT)) OVER() TTL_ORD_AMT
FROM
	M_CUS t1
	, T_ORD_BIG t2
WHERE
	t1.CUS_ID = t2.CUS_ID 
	AND t2.ORD_YMD LIKE '201702%'
GROUP BY t1.CUS_ID;

-- Merge Join 인덱스 전략
-- Merge Join 을 수행할 테이블에 where 조건절이 있으면 각 조건별로 인덱스를 구성한다. (Table Access Full 보다 성능이 좋아야 함)
-- Full, X_T_ORD_BIG_1, X_T_ORD_BIG_3, X_T_ORD_BIG_4 을 모두 사용해본다. (where 절 컬럼이 포함되는 인덱스들)
SELECT
	/*+ GATHER_PLAN_STATISTICS LEADING(t1) USE_MERGE(t2) FULL(t2) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_AMT) ORD_AMT
	, SUM(SUM(t2.ORD_AMT)) OVER() TTL_ORD_AMT
FROM
	M_CUS t1
	, T_ORD_BIG t2
WHERE
	t1.CUS_ID = t2.CUS_ID 
	AND t2.ORD_YMD BETWEEN '20170201' AND '20170210'
GROUP BY t1.CUS_ID;


----------------------------------------------------------------------------------------------------
-- HASH 조인과 성능
----------------------------------------------------------------------------------------------------
-- 많은 양의 데이터를 조인하면서도, MERGE JOIN 에서의 데이터 정렬을 하지 않는 장점이 있다.
SELECT
	/*+ GATHER_PLAN_STATISTICS LEADING(t1) USE_HASH(t2) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_AMT) ORD_AMT
	, SUM(SUM(t2.ORD_AMT)) OVER() TTL_ORD_AMT
FROM
	M_CUS t1
	, T_ORD_BIG t2
WHERE t1.CUS_ID = t2.CUS_ID 
GROUP BY t1.CUS_ID;

-- NL JOIN 과 마찬가지로 HASH JOIN 에서도 선행집합 선택이 중요하다.
-- 선행집합은 빌드 입력(build-input) 으로 처리하고, 후행집합은 검증 입력(probe-input) 으로 처리된다.
-- 빌드 입력의 데이터가 적을수록 성능에 유리하고, 빌드 입력이 해시 영역에 모두 위치해야 최고의 성능을 낼 수 있다.
-- 메모리에 모두 올릴 수 없으면 임시공간을 사용하게 되므로 성능저하가 발생한다.

-- 큰 데이터를 선행집합으로 뒀을 때 비교
SELECT
	/*+ GATHER_PLAN_STATISTICS LEADING(t2) USE_HASH(t1) */
	t1.CUS_ID
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, COUNT(*) ORD_CNT
	, SUM(t2.ORD_AMT) ORD_AMT
	, SUM(SUM(t2.ORD_AMT)) OVER() TTL_ORD_AMT
FROM
	M_CUS t1
	, T_ORD_BIG t2
WHERE t1.CUS_ID = t2.CUS_ID 
GROUP BY t1.CUS_ID;

-- 소량의 데이터에도 해시 조인은 유용하다.
-- 모든 SQL 을 NL 조인으로 변경할 필요는 없다.
-- 특정 SQL 이 매우 많이 사용되면서 CPU 점유시간이 높다면 HASH JOIN 을 제거하는 방법을 고민해 봐야한다. 이런 경우가 아니라면 굳이 제거할 필요는 없다.

-- 자주 실행되는 SQL 은 NL 조인만으로 처리하는 것이 전체 성능에 좋다. (적절한 인덱스 필요)
-- 대량의 데이터를 조회해서 분석해야 한다면 HASH JOIN 이 좋다.
-- Merge JOIN 이 활용되는 경우는 많지 않다.
-- 옵티마이저보다 앞서서 어떤 조인 방식이 좋을지 예측할 수 있어야 한다.