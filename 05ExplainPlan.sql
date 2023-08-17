-- SQL 성능 개선
-- 실행계획, 옵티마이저, IO

-- SQL 처리 순서: 구문분석 - 실행계획 - 처리

-- 실행계획 dbeaver 단축키: ctrl+shift+E

-- EXPLAIN PLAN FOR 을 입력하면 실행계획을 만들어 PLAN 테이블에 저장한다.
EXPLAIN PLAN FOR 
SELECT * FROM T_ORD WHERE ORD_SEQ = 4;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());
-- 실행계획은 가장 낮은 자식 단계부터 처리된다.
-- 이는 예상 실행계획이고, 자세한 성능 저하의 원인을 찾고자 할 때는 실제 실행계획을 확인한다.

-- 실행계획: M_CUS 와 T_ORD 를 Full scan 하여 HashJoin 한다.
SELECT *
FROM
	T_ORD t1
	, M_CUS t2
WHERE
	t1.CUS_ID = t2.CUS_ID 
	AND t1.ORD_DT >= TO_DATE('20170101', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20180201', 'YYYYMMDD')
	AND t2.CUS_GD = 'A';

-- 실행계획: M_ITM
SELECT 
	t3.ITM_ID 
	, SUM(t2.ORD_QTY) ORD_QTY
FROM
	T_ORD t1
	, T_ORD_DET t2
	, M_ITM t3
WHERE
	t1.ORD_SEQ = t2.ORD_SEQ 
	AND t2.ITM_ID = t3.ITM_ID 
	AND t1.ORD_DT >= TO_DATE('20170101', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20180201', 'YYYYMMDD')
	AND t3.ITM_TP = 'ELEC'
GROUP BY t3.ITM_ID;

-- 실제 실행계획 확인하는 방법
-- GATHER_PLAN_STATISTICS 힌트를 사용한다.
-- GATHER_PLAN_STATISTICS 힌트를 추가해 SQL 을 실행하면, 자세한 실행정보가 저장되고, DBMS_XPLAN.DISPLAY_CURSOR 를 이용하여 확인할 수 있다.
-- V_$SQL, V_$SQL_PLAN_STATISTICS_ALL, V_$SQL_PLAN, V_$SESSION 에 권한부여를 해야 가능하다.

-- 힌트를 넣고 실행한다.
SELECT
	/*+ GATHER_PLAN_STATISTICS */
	*
FROM
	T_ORD t1
	, M_CUS t2
WHERE
	t1.CUS_ID = t2.CUS_ID
	AND t1.ORD_DT >= TO_DATE('20170101', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20170201', 'YYYYMMDD')
	AND t2.CUS_GD = 'A';

-- 저장된 실행계획의 SQL_ID, CHILD_NUMBER 를 찾는다.
SELECT
	t1.SQL_ID
	, t1.CHILD_NUMBER 
	, t1.SQL_TEXT 
FROM V$SQL t1
WHERE t1.SQL_TEXT LIKE '%GATHER_PLAN_STATISTICS%'
ORDER BY t1.LAST_ACTIVE_TIME DESC;

-- SQL_ID 와 CHILD_NUMBER 를 이용하여 실제 실행계획을 출력한다.
SELECT 
	*
FROM table(DBMS_XPLAN.DISPLAY_CURSOR('6turf6znfu4gr', 0, 'ALLSTATS LAST'));
-- 실제 실행계획 중 다음 항목을 주의 깊게 봐야한다.
-- A-Rows: 해당 단계의 실제 데이터 건수
-- A-Time: 해당 단계까지 수행된 시간, 누적
-- Buffers: 해당 단계까지 메모리 버퍼에서 읽은 블록 수, 논리적 IO 횟수, 누적


-- 옵티마이저: SQL 을 실행하기 전에 실행계획을 만드는 역할
-- 비용 기반 옵티마이저: SQL 을 처리하는 비용에 기반해 최소의 비용을 목표로 실행계획을 만든다. 대부분의 RDMBS 는 비용기반
-- 규칙 기반 옵티마이저: 일정한 규칙에 따라 실행계획을 만든다.

-- 비용이란? IO 횟수, CPU time, 메모리 사용량
-- 비용 산출 시 중요한 것은 테이블의 통계 정보

-- 구문분석: SQL 이 문법에 맞는지, 사용한 오브젝트(테이블, 컬럼, 뷰 등) 이 사용 가능한지 검사한다.
-- 소프트파싱: 구문분석만 하고 실행계획은 재사용하는 것. 구문분석을 통과한 후 메모리에 실행계획이 있는지 검색하여, 만들어 놓은 실행계획이 있으면 재사용한다.
-- 하드파싱: 구문분석 이후에 실행계획까지 만드는 과정. 실행계획을 만드는 과정은 큰 비용이 소모된다. 가능한 소프트 파싱이 가능하도록 SQL 을 작성해야 한다.

-- 다음 SQL 은 다른 SQL 이므로, 각각 하드파싱 된다.
SELECT * FROM T_ORD t1 WHERE t1.CUS_ID = 'CUS_0001';
SELECT * FROM T_ORD t1 WHERE t1.CUS_ID = 'CUS_9999';

-- 바인드 변수로 처리하여, 처음 SQL 을 실행할 때만 하드파싱되고, 이후에는 소프트 파싱되도록 한다.
-- 요즘 대부분의 개발 프레임웍에서는 바인드 변수를 사용한다.
SELECT * FROM T_ORD t1 WHERE t1.CUS_ID = :v_CUS_ID;

-- 바인드 변수 값에 따른 성능 저하
-- 1건조회 이후 10만건 조회하는 경우
-- 1건 조회 시에는 인덱스를 이용하는 것이 빠르므로, 인덱스 이용하는 실행계획을 만든다. 
-- 10만건 조회 할 때는, 1건 조회 시의 실행계획을 이용하면서 성능 저하가 발생할 수 있다.
-- 그럼에도 OLTP 시스템에서는 소프트 파싱으로 개발해야 한다.

-- IO: DB 에서 가장 많이 발생하는 작업이고, 성능 개선 시 불필요한 IO 가 발생하지 않는지 확인해야 한다. 적절한 인덱스 사용
-- Block(Page): IO 를 처리하는 최소 단위. 한 블록에 여러 건의 데이터가 들어갈 수 있다. (블록크키 / 데이터 1건 크기) 블록 내부에서 데이터 한 건을 찾는 속도는 빠르기 때문에 걱정할 필요가 없다.
-- 테이블 설계 시 최소 크기로 데이터가 저장되도록 테이블을 설계해야 한다. 그래야 블록 한 개에 들어가는 데이터의 개수가 많아지고, IO 횟수도 줄어든다.

SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	count(*)
FROM T_ORD t1
WHERE
	t1.ORD_DT >= TO_DATE('20170101', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20170201', 'YYYYMMDD');

SELECT 
	t.SQL_ID 
	, t.CHILD_NUMBER 
	, t.SQL_TEXT 
FROM V$SQL t
WHERE t.SQL_TEXT LIKE '%GATHER_PLAN_STATISTICS%'

SELECT 
	*
FROM table(DBMS_XPLAN.DISPLAY_CURSOR('fa0q4d43yunfu', 0, 'ALLSTATS LAST'));

-- 논리적IO: 실행계획의 Buffers, 메모리 영역에서 데이터를 읽고 쓰는 작업
-- 물리적IO: 실행계획의 Reads, 디스크에서 데이터를 읽고 쓰는 작업

-- 부분 범위 처리: select 결과를 화면에 보이는 부분만 먼저 보여준다. 스크롤을 모두 내린 후 다시 실행계획을 보면 IO 횟수가 달라져 있는 것을 볼 수 있다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	t1.*
FROM T_ORD t1
WHERE t1.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD');

-- GROUP BY, SUM 등 집계함수가 사용되면 부분 범위 처리를 할 수 없다. Order by 도 마찬가지이다.
-- Table Access full 단계에서 모든 rows 를 다 읽는 것을 실행계획에서 확인할 수 있다.
SELECT 
	/*+ GATHER_PLAN_STATISTICS */
	TO_CHAR(t1.ORD_DT, 'YYYYMM')
	, t1.CUS_ID
FROM T_ORD t1
WHERE t1.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
GROUP BY TO_CHAR(t1.ORD_DT, 'YYYYMM'), t1.CUS_ID;