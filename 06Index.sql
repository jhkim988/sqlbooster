-- 인덱스 테스트를 위한 테이블 생성
CREATE TABLE T_ORD_BIG AS
SELECT
	t1.*
	, t2.RNO
	, TO_CHAR(t1.ORD_DT, 'YYYYMMDD') ORD_YMD
FROM
	T_ORD t1
	, ( SELECT ROWNUM RNO FROM DUAL CONNECT BY ROWNUM <= 10000 ) t2;
	
-- 테이블의 통계를 생성하는 명령, 올바른 성능 테스트를 위해서는 통계 정보를 반드시 만들어야 한다.
EXEC DBMS_STATS.GATHER_TABLE_STATS('ORA_SQL_TEST', 'T_ORD_BIG'); -- 실행 안돼서 sqlplus 에서 직접 실행함

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
FROM TABLE(dbms_xplan.display_cursor('af50htyz56b3b', 0, 'ALLSTATS LAST'));
----------------------------------------------------------------------------------------------------

-- 인덱스 없이 실행, Buffer 258K, Reads 258K
-- 인덱스 만든 후 실행, Buffer 24
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	count(*)
FROM T_ORD_BIG t1
WHERE t1.ORD_SEQ = 343;

CREATE INDEX X_T_ORD_BIG_TEST ON T_ORD_BIG(ORD_SEQ);

-- 단일인덱스: 인덱스에 하나의 컬럼만 사용, 주로 pk 속성이 단일컬럼일 때 
-- 복합인덱스: 인덱스에 두 개 이상의 컬럼을 사용, 가능한 하나의 복합인덱스로 여러 SQL 의 성능을 커버해야 좋다.

-- 유니크 인덱스: 인덱스 구성 컬럼들 값에 중복 허용하지 않음
-- 비유니크 인덱스: 중복 허

-- 인덱스의 물리적 구조에 따른 구분
-- B*트리 인덱스: OLTP 시스템에서 주로 사용하는 인덱스
-- 비트맵 인덱스: 값의 종류가 많지 않은 컬럼에 사용하는 인덱스 
-- IOT: 테이블 자체를 특정 컬럼 기준으로 인덱스화, MS-SQL, MySQL 의 클러스터드 인덱스.

-- 파티션 테이블, 파티션 된 인덱스, 글로벌 인덱스, 로컬 인덱스 

-- 데이터를 읽는 방법
-- Table Access Full
-- 테이블 전체 읽기, 인덱스가 없거나, 인덱스 보다 전체를 읽는 것이 더 효율적이라고 판단될 때 사용
-- 테이블 블록 전체를 읽기 때문에, 테이블이 클수록 오래 걸린다.
-- 찾아야 하는 데이터가 많다면 full scan 이 오히려 효율적일 수도 있다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	t1.CUS_ID 
	, COUNT(*) ORD_CNT
FROM T_ORD_BIG t1
WHERE t1.ORD_YMD = '20170316'
GROUP BY t1.CUS_ID 
ORDER BY t1.CUS_ID;

-- Index Range Scan & Table Acdcess By Index RowID
-- : 인덱스를 이용한 찾기, 1, 2 과정을 Index Range Scan 이라고 한다.
-- 1. 루트에서 리프 블록으로
-- 2. 리프 블록 스캔
-- 3. 테이블 접근 - 리프블록 스캔 과정에서는 필요에 따라 ROWID를 참조하여 테이블 접근을 한다. 인덱스 값만 이용하여 처리할 수 있으면 생략된다.
-- Table Access By Index RowId: RowID 를 이용한 직접 찾기
CREATE INDEX X_T_ORD_BIG_1 ON T_ORD_BIG(ORD_YMD);
SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(T X_T_ORD_BIG_1) */
	t.CUS_ID
	, count(*) ORD_CNT
FROM T_ORD_BIG t
WHERE t.ORD_YMD = '20170316'
GROUP BY t.CUS_ID 
ORDER BY t.CUS_ID;

-- 랜덤 액세스: IO 작업 한 번에 하나의 블록을 가져오는 접근 방법, 찾으려는 데이터가 적으면 나쁘지 않지만, 많으면 비효율적이다.
-- T_ORD_BIG 은 총 3,000만건 데이터, ORD_YMD 가 '20170316'인 데이터는 5만건 정도이다. -> Index range scan 이 효율적이다. (정확히는 블록 수로 판단해야 한다.)
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	t.CUS_ID 
	,count(*) ORD_CNT
FROM T_ORD_BIG t
WHERE t.ORD_YMD = '20170316'
GROUP BY t.CUS_ID 
ORDER BY t.CUS_ID;

-- T_ORG_BIG 3개월간의 주문 조회, 총 765만건, 인덱스를 사용하도록 힌트를 주면 매우 느리게 실행된다. INDEX(t X_T_ORD_BIG_1)
-- 실행계획을 보면 매우 많은 랜덤액세스가 발생한 것을 확인할 수 있다.
-- 테이블 전체를 스캔하도록 힌트를 주면 속도가 빨라진다. Full(t)
SELECT 
	/*+ GATHER_PLAN_STATISTICS FULL(t) */
	t.ORD_ST 
	, sum(t.ORD_AMT)
FROM T_ORD_BIG t
WHERE t.ORD_YMD BETWEEN '20170401' AND '20170630'
GROUP BY t.ORD_ST;
-- 데이터가 계속 쌓이는 구조라면, full scan 방식은 시간이 지날수록 성능이 나빠진다.
-- 오래된 데이터를 잘라내거나, 파티션 전략을 수립할 필요가 있다. 중간 집계 테이블을 활용할 수도 있다.

-- 단일 인덱스: 컬럼을 선정하는 방법
-- where 조건절에 사용된 컬럼에 인덱스를 구성하는 것이 기본원리다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	TO_CHAR(t.ORD_DT, 'YYYYMM')
	, COUNT(*)
FROM T_ORD_BIG t
WHERE
	t.CUS_ID = 'CUS_0064'
	AND t.PAY_TP = 'BANK'
	AND t.RNO = 2
GROUP BY TO_CHAR(t.ORD_DT, 'YYYYMM')

-- 그러나 모든 where 컬럼에 인덱스를 만들 수는 없다. 효율적인 컬럼을 찾아본다.
-- 선별성이 좋은 컬럼을 찾아야 한다. count 를 이용하여 적은 개수를 찾아 인덱스로 만든다.
SELECT 'CUS_ID' COL, COUNT(*) CNT FROM T_ORD_BIG t WHERE t.CUS_ID = 'CUS_0064' UNION ALL 
SELECT 'PAY_TP' COL, COUNT(*) CNT FROM T_ORD_BIG t WHERE t.PAY_TP = 'BANK' UNION ALL 
SELECT 'RNO' COL, COUNT(*) CNT FROM T_ORD_BIG t WHERE t.RNO= 2;

CREATE INDEX X_T_ORD_BIG_2 ON T_ORD_BIG(RNO);

SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(t X_T_ORD_BIG_2) */
	TO_CHAR(t.ORD_DT, 'YYYYMM')
	, COUNT(*)
FROM T_ORD_BIG t
WHERE
	t.CUS_ID = 'CUS_0064'
	AND t.PAY_TP = 'BANK'
	AND t.RNO = 2
GROUP BY TO_CHAR(t.ORD_DT, 'YYYYMM');

-- RNO 보다 선별성이 좋지 않은 CUS_ID 로 인덱스를 만들어 테스트해본다.
CREATE INDEX X_T_ORD_BIG_3 ON T_ORD_BIG(CUS_ID);
SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(t X_T_ORD_BIG_3) */
	TO_CHAR(t.ORD_DT, 'YYYYMM')
	, COUNT(*)
FROM T_ORD_BIG t
WHERE
	t.CUS_ID = 'CUS_0064'
	AND t.PAY_TP = 'BANK'
	AND t.RNO = 2
GROUP BY TO_CHAR(t.ORD_DT, 'YYYYMM');

-- 단일인덱스 vs 복합인덱스
-- 복합 인덱스는 여러 개의 인덱스 효과를 낼 수 있다.
-- 데이터 변경 시 인덱스도 수정을 하는데, 인덱스 수가 많으면 수정할 인덱스도 많기 때문에 성능 저하가 발생한다.
-- 따라서 복합 인덱스로 인덱스 수를 압축하는게 중요하다.
-- CUS_ID 인덱스 제거
DROP INDEX X_T_ORD_BIG_3;

SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(t X_T_ORD_BIG_1) */
	t.ORD_ST 
	, count(*)
FROM T_ORD_BIG t
WHERE
	t.ORD_YMD LIKE '201703%'
	AND t.CUS_ID = 'CUS_0075'
GROUP BY t.ORD_ST;

-- where 조건에 사용된 ORD_YMD, CUS_ID 컬럼 두 개를 모두 포함하는 복합인덱스를 만든다.
CREATE INDEX X_T_ORD_BIG_3 ON T_ORD_BIG(ORD_YMD, CUS_ID);
SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(t X_T_ORD_BIG_3) */
	t.ORD_ST 
	, count(*)
FROM T_ORD_BIG t
WHERE
	t.ORD_YMD LIKE '201703%'
	AND t.CUS_ID = 'CUS_0075'
GROUP BY t.ORD_ST;

-- 인덱스 설계 시 중요한 것은, 테이블 접근(table access by row id)을 줄이는 것이다.
-- 너무 많은 컬럼을 인덱스로 구성하면 입력/수정/삭제에서 성능저하가 나타난다. 적절한 칼럼 수로 구성해야한다.


-- 복합인덱스: 컬럼 선정과 순서
-- 같다(=) 조건이 사용된 컬럼을 앞의 순서로 둔다.
CREATE INDEX X_T_ORD_BIG_4 ON T_ORD_BIG(CUS_ID, ORD_YMD);
SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(t X_T_ORD_BIG_4) */
	t.ORD_ST 
	, count(*)
FROM T_ORD_BIG t
WHERE
	t.ORD_YMD LIKE '201703%'
	AND t.CUS_ID = 'CUS_0075'
GROUP BY t.ORD_ST;

-- 하나의 복합 인덱스가 특정 SQL 에는 효율적일 수 있지만, 다른 SQL 에는 비효율적일 수 있다. 따라서 적절한 인덱스를 사용해야한다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(t X_T_ORD_BIG_3) */
	t.ORD_ST 
	, count(*)
FROM T_ORD_BIG t
WHERE
	t.ORD_YMD = '20170301'
	AND t.CUS_ID LIKE 'CUS_001%'
GROUP BY t.ORD_ST;

-- 3개의 조건
-- index 후보 (CUS_ID, PAY_TP, ORD_YMD), (PAY_TP, CUS_ID, ORD_YMD)
SELECT 
	t.ORD_ST 
	, COUNT(*)
FROM T_ORD_BIG t
WHERE 
	t.ORD_YMD LIKE '201704%'
	AND t.CUS_ID = 'CUS_0042'
	AND t.PAY_TP = 'BANK'
GROUP BY T.ORD_ST;
-- 다음 SQL도 커버할 수 있어야 한다면. (CUS_ID, PAY_TP, ORD_YMD) 를 사용하는 것이 좋다.
-- (PAY_TP, CUS_ID, ORD_YMD) 를 사용해도 성능이 크게 나쁘지 않는데, oracle 의 Index Skip Scan 기능으로 복합 인덱스의 가운데 컬럼을 인덱스 검색에 어느 정도 활용할 수 있기 때문이다.
-- 업무적으로 CUS_ID 에 등호조건이 있을 가능성이 높으므로, (CUS_ID, PAY_TP, ORD_YMD) 를 사용하는 것이 좋다.
SELECT 'X'
FROM DUAL A
WHERE EXISTS (
	SELECT *
	FROM T_ORD_BIG t
	WHERE t.CUS_ID = 'CUS_0042'
);

-- 많은 조건이 걸리는 SQL
SELECT
	/*+ GATHER_PLAN_STATISTICS INDEX(t X_T_ORD_BIG_3) */
	count(*)
FROM T_ORD_BIG t
WHERE
	t.ORD_AMT = 2400
	AND t.PAY_TP = 'CARD'
	AND t.ORD_YMD = '20170406'
	AND t.ORD_ST = 'COMP'
	AND t.CUS_ID = 'CUS_0036';
-- 성능에 도움이 되는 컬럼을 선정하여 인덱스를 구성한다.
SELECT 'ORD_AMT' COL, count(*) CNT FROM T_ORD_BIG t WHERE t.ORD_AMT = 2400 UNION ALL
SELECT 'PAY_TP' COL, count(*) CNT FROM T_ORD_BIG t WHERE t.PAY_TP = 'CARD' UNION ALL 
SELECT 'ORD_YMD' COL, count(*) CNT FROM T_ORD_BIG t WHERE t.ORD_YMD = '20170406' UNION ALL 
SELECT 'ORD_ST' COL, count(*) CNT FROM T_ORD_BIG t WHERE t.ORD_ST = 'COMP' UNION ALL 
SELECT 'CUS_ID' COL, count(*) CNT FROM T_ORD_BIG t WHERE t.CUS_ID = 'CUS_0036' 
-- ORD_YMD 와 CUS_ID 로 인덱스를 구성하면 충분히 성능이 나올 것이다.
-- 실행계획에서 A-ROWS 의 값이, Index range scan 과 table access 에서 같다. 인덱스를 더 추가할 필요가 없다.

-- Covering Index
-- 테이블 접근 횟수를 줄이는 것이 중요한데, 아예 접근 자체를 생략할 수 있다면 더 좋다.
-- 테이블 접근 3만 회, 인덱스에 ORD_ST 컬럼이 없기 때문에 테이블에 접근하여 값을 확인한다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS INDEX(t X_T_ORD_BIG_4) */
	t.ORD_ST
	, COUNT(*)
FROM T_ORD_BIG t
WHERE 
	t.ORD_YMD LIKE '201703%'
	AND t.CUS_ID = 'CUS_0075'
GROUP BY t.ORD_ST;

-- X_T_ORD_BIG_4 를 제거하고, ORD_ST 컬럼을 추가하여 다시 인덱스를 만들어본다. 
DROP INDEX X_T_ORD_BIG_4;
CREATE INDEX X_T_ORD_BIG_4 ON T_ORD_BIG(CUS_ID, ORD_YMD, ORD_ST);
-- Buffers 가 줄어든 것을 확인할 수 있다.
-- 그러나 모든 SQL 에 이처럼 생성하면 안된다. 데이터의 변경 성능이 나빠지고, 요구사항이 수시로 변경되면서 where 절에 새로운 column 이 추가되면 다시 테이블 접근이 생긴다.

-- Predicate Information - Access
-- CUS_0075 의 201703 주문을 조회하는 SQL
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	t.ORD_ST
	, count(*)
FROM T_ORD_BIG t
WHERE
	SUBSTR(t.ORD_YMD, 1, 6) = '201703' 
	AND t.CUS_ID = 'CUS_0075'
GROUP BY t.ORD_ST;
-- 실행계획의 Predicate Information 을 살펴보면, CUS_ID 조건은 access, SUBSTR() = '201703' 은 filter 로 처리하고 있다.
-- access 는 인덱스 리프 블록의 스캔 시작위치를 찾 데 사용한 조건이고, filter 는 리프블록을 차례대로 스캔하면서 처리한 조건이다.
-- 인덱스를 제대로 탔다면 ORD_YMD 조건도 access 에 표시돼야 한다. SUBSTR 로 ORD_YMD 컬럼을 변형해서 인덱스를 제대로 사용하지 못한 것이다.

-- Like 조건을 사용한다
-- access 에 ORD_YMD 조건이 추가된 것을 확인할 수 있다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	t.ORD_ST
	, count(*)
FROM T_ORD_BIG t
WHERE
	t.ORD_YMD LIKE '201703%' 
	AND t.CUS_ID = 'CUS_0075'
GROUP BY t.ORD_ST;

-- 앞쪽 % 도 access 를 CUS_ID 로만 하는 것을 확인할 수 있다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	t.ORD_ST
	, count(*)
FROM T_ORD_BIG t
WHERE
	t.ORD_YMD LIKE '%03%' 
	AND t.CUS_ID = 'CUS_0075'
GROUP BY t.ORD_ST;

-- 인덱스의 크기
-- 인덱스 크기를 합치면 테이블보다 커진다. insert 할 때 모든 인덱스에 insert 된다.
-- 인덱스를 신중히 만들어야 한다.
SELECT 
	t1.SEGMENT_NAME
	, t1.SEGMENT_TYPE
	, t1.BYTES / 1024 / 1024 AS SIZE_MB
	, t1.BYTES / t2. CNT BYTE_PER_ROW
FROM
	DBA_SEGMENTS t1
	, (SELECT count(*) CNT FROM ORA_SQL_TEST.T_ORD_BIG) t2
WHERE 
	t1.segment_name LIKE '%ORD_BIG%'
ORDER BY t1.SEGMENT_NAME;