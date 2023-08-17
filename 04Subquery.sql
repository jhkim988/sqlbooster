-- 서브쿼리 유의점: SQL 실행계획이 특정된 방법으로 제약될 가능성이 있어, 성능이 좋지 못할 수 있다.
-- 서브쿼리 종류 4가지 select/where 절의 단독/상관 서브쿼리 
-- 단독서브쿼리: 메인 SQL 에 상관 없이 실행할 수 있는 서브쿼리
-- 상관서브쿼리: 메인 SQL 에서 값을 받아 처리하는 서브쿼리 

-- select 절에서 사용되는 서브쿼리는 스칼라 서브쿼리라고 부른다.

-- 17년 8월 총 주문금액, 주문금액비율 구하기
-- T_ORD 테이블에 반복접근하므로 성능도 나빠지고, 수정할 때 여러 곳을 수정해야하기 때문에 유지보수에도 좋지 않다.
SELECT 
	to_char(t1.ORD_DT, 'YYYYMMDD') ORD_YMD
	, sum(t1.ORD_AMT) ORD_AMT
	, (
		SELECT sum(A.ORD_AMT)
		FROM T_ORD A
		WHERE A.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD') AND A.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
	) total_ord_amt
	, ROUND(
		SUM(t1.ORD_AMT) / (
		SELECT
			sum(A.ORD_AMT)
		FROM T_ORD A
		WHERE A.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD') AND A.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
	) * 100, 2) ord_amt_rt
FROM T_ORD t1
WHERE 
	t1.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD')
	AND t1. ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
GROUP BY t1.ORD_DT

-- 인라인뷰를 사용하여 반복 서브쿼리 제거 
SELECT 
	t1.ORD_YMD
	, t1.ORD_AMT
	, t1.TOTAL_ORD_AMT
	, ROUND(t1.ORD_AMT/t1.TOTAL_ORD_AMT*100,2) ORD_AMT_RT
FROM (
	SELECT
		TO_CHAR(t1.ORD_DT, 'YYYYMMDD') ORD_YMD
		, SUM(t1.ORD_AMT) ORD_AMT
		, (
			SELECT SUM(A.ORD_AMT)
			FROM T_ORD A
			WHERE 
				A.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD')
				AND A.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
		) TOTAL_ORD_AMT
	FROM T_ORD t1
	WHERE 
		t1.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD')
		AND t1.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
	GROUP BY TO_CHAR(t1.ORD_DT, 'YYYYMMDD')
) t1;

-- Cartesian Join 이용해서 반복 서브쿼리 제거
SELECT
	TO_CHAR(t1.ORD_DT, 'YYYYMMDD') ORD_YMD
	, SUM(t1.ORD_AMT) ORD_AMT
	, MAX(t2.TOTAL_ORD_AMT)
	, ROUND(SUM(t1.ORD_AMT) / MAX(t2.TOTAL_ORD_AMT) * 100, 2) ORD_AMT_RT
FROM 
	T_ORD t1
	, (
		SELECT SUM(A.ORD_AMT) TOTAL_ORD_AMT
		FROM T_ORD A
		WHERE 
			A.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD')
			AND A.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
	) t2
WHERE 
	t1.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
GROUP BY TO_CHAR(t1.ORD_DT, 'YYYYMMDD')

-- select 절의 상관쿼리
-- 코드성 데이터의 명칭을 가져오기 위해 사용할 수 있다.
-- join 을 대신해서 사용할 수 있지만, 너무 남용하면 안된다.
-- 코드처럼 값의 종류가 많지 않은 경우는, 서브쿼리 캐싱 효과로 성능이 더 좋아질 수 있다.
SELECT
	t1.ITM_TP 
	, (
		SELECT A.BAS_CD_NM
		FROM C_BAS_CD A
		WHERE A.BAS_CD_DV = 'ITM_TP' AND A.BAS_CD = t1.ITM_TP AND A.LNG_CD = 'KO'
	) ITM_TP_NM
FROM M_ITM t1

-- 반복되는 상관 서브쿼리
-- 아래의 SQL 은 join 으로 처리하는 것이 좋다. 불필요하게 M_CUS 에 두 번 접근할 필요가 없다.
SELECT 
	t1.CUS_ID 
	, TO_CHAR(t1.ORD_DT, 'YYYYMMDD') ORD_YMD
	, (SELECT A.CUS_NM FROM M_CUS A WHERE A.CUS_ID = t1.CUS_ID) CUS_NM
	, (SELECT A.CUS_GD FROM M_CUS A WHERE A.CUS_ID = t1.CUS_ID) CUS_GD
	, t1.ORD_AMT
FROM T_ORD t1
WHERE
	t1.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
	
-- 인라인뷰가 포함된 SQL
-- 인라인뷰 바깥으로 옮겨서 서브쿼리 실행횟수를 줄일 수 있다.
-- 예를 들어 인라인뷰 결과가 1000건이고 Group by 로 최종 100건만 나온다면, 서브쿼리를 인라인뷰 안에 넣었을 때 서브쿼리 실행 횟수는 1000번이다.
-- 그러나 바깥으로 옮기면 서브쿼리는 100번만 실행되게 된다.
SELECT
	t1.CUS_ID
	, SUBSTR(t1.ORD_YMD, 1, 6) ORD_YM
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, t1.ORD_ST_NM
	, t1.PAY_TP_NM
	, SUM(t1.ORD_AMT) ORD_AMT 
FROM (
	SELECT
		t1.CUS_ID
		, TO_CHAR(t1.ORD_DT, 'YYYYMMDD') ORD_YMD
		, t2.CUS_NM
		, t2.CUS_GD
		, (SELECT A.BAS_CD_NM FROM C_BAS_CD A WHERE A.BAS_CD_DV = 'ORD_ST' AND A.BAS_CD = t1.ORD_ST AND A.LNG_CD = 'KO') ORD_ST_NM
		, (SELECT A.BAS_CD_NM FROM C_BAS_CD A WHERE A.BAS_CD_DV = 'PAY_TP' AND A.BAS_CD = t1.PAY_TP AND A.LNG_CD = 'KO') PAY_TP_NM
		, t1.ORD_AMT
	FROM T_ORD t1, M_CUS t2
	WHERE
		t1.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD')
		AND t1.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
		AND t1.CUS_ID = t2.CUS_ID
) t1
GROUP BY t1.CUS_ID, SUBSTR(t1.ORD_YMD, 1, 6), t1.ORD_ST_NM, t1.PAY_TP_NM;

-- 바깥으로 옮겼다.
SELECT
	t1.CUS_ID
	, SUBSTR(t1.ORD_YMD, 1, 6) ORD_YM
	, MAX(t1.CUS_NM) CUS_NM
	, MAX(t1.CUS_GD) CUS_GD
	, MAX((SELECT A.BAS_CD_NM FROM C_BAS_CD A WHERE A.BAS_CD_DV = 'ORD_ST' AND A.BAS_CD = t1.ORD_ST AND A.LNG_CD = 'KO')) ORD_ST_NM
	, MAX((SELECT A.BAS_CD_NM FROM C_BAS_CD A WHERE A.BAS_CD_DV = 'PAY_TP' AND A.BAS_CD = t1.PAY_TP AND A.LNG_CD = 'KO')) PAY_TP_NM
	, SUM(t1.ORD_AMT) ORD_AMT 
FROM (
	SELECT
		t1.CUS_ID
		, TO_CHAR(t1.ORD_DT, 'YYYYMMDD') ORD_YMD
		, t2.CUS_NM
		, t2.CUS_GD
		, t1.ORD_ST
		, t1.PAY_TP
		, t1.ORD_AMT
	FROM T_ORD t1, M_CUS t2
	WHERE
		t1.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD')
		AND t1.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
		AND t1.CUS_ID = t2.CUS_ID
) t1
GROUP BY t1.CUS_ID, SUBSTR(t1.ORD_YMD, 1, 6), t1.ORD_ST, t1.PAY_TP;

-- 서브쿼리 안에서 조인
SELECT 
	t1.ORD_DT 
	, t2.ORD_QTY
	, t2.ITM_ID
	, t3.ITM_NM
	, (
		SELECT 
			SUM(B.EVL_PT) / COUNT(*)
		FROM M_ITM A, T_ITM_EVL B
		WHERE
			A.ITM_TP = t3.ITM_TP 
			AND A.ITM_ID = B.ITM_ID
			AND B.EVL_DT < T1.ORD_DT
	) ITM_TP_EVL_PT_AVG
FROM
	T_ORD t1
	, T_ORD_DET t2
	, M_ITM t3
WHERE 
	t1.ORD_DT >= TO_DATE('20170801', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20170901', 'YYYYMMDD')
	AND t2.ITM_ID = t3.ITM_ID 
	AND t1.ORD_SEQ = t2.ORD_SEQ 
ORDER BY t1.ORD_DT, t2.ITM_ID;

-- 상관 서브쿼리는 메인 SQL 의 결과 건수만큼 반복수행된다. 성능에 문제가 없는지 확인해야 한다.
-- 상관서브쿼리의 where 절 컬럼은 적절한 인덱스가 필수다. 인덱스가 있어도 성능이 느리다면, 상관서브쿼리를 제거해야한다.
-- 메인 SQL 의 조회 결과 건수가 적을 때만 상관 서브쿼리를 사용한다.
-- 코드값처럼 값의 종류가 적을 때는 성능이 좋아질 수도 있다. (서브쿼리 캐싱)


-- select 절 서브쿼리 - 단일값
-- select 절의 서브쿼리는 단일값을 내보내야 한다. 즉, 1개의 row, 1개의 col

-- 고객별 마지막 주문의 주문금액
-- select 절의 서브쿼리는 결과 데이터의 개수만큼 반복된다. 조회되는 건수가 작을 때만 이런 방법을 이용한다.
SELECT 
	t1.CUS_ID 
	, t1.CUS_NM 
	, (
		SELECT 
			B.ORD_AMT 
		FROM T_ORD B
		WHERE B.ORD_SEQ = (SELECT MAX(A.ORD_SEQ) FROM T_ORD A WHERE A.CUS_ID = t1.CUS_ID)
	) LAST_ORD_AMT
FROM M_CUS t1
ORDER BY t1.CUS_ID;

-- where 절 단독서브쿼리
SELECT
	*
FROM T_ORD t1
WHERE t1.ORD_SEQ = (SELECT MAX(A.ORD_SEQ) FROM T_ORD A);
-- T_ORD 에 두 번 접근한다. 다음과 같이 개선할 수 있다.
-- ORD_SEQ 에 인덱스가 있어야 성능상의 이점을 얻을 수 있다.
SELECT * FROM (
	SELECT * FROM T_ORD t1 ORDER BY t1.ORD_SEQ DESC
) A
WHERE ROWNUM <= 1;

-- 마지막 주문 일자의 주문
SELECT
	*
FROM T_ORD t1
WHERE t1.ORD_DT = (SELECT MAX(A.ORD_DT) FROM T_ORD A);

-- In 조건을 사용
-- 3월 주문 건수가 4건 이상인 고객의 3월달 주문 리스트
SELECT 
	*
FROM T_ORD t1
WHERE
	t1.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
	AND t1.CUS_ID IN (
		SELECT 
			A.CUS_ID 
		FROM T_ORD A
		WHERE
			A.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
			AND A.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
		GROUP BY A.CUS_ID
		HAVING COUNT(*) >= 4
	)
ORDER BY t1.ORD_SEQ;

-- 인라인뷰를 이용한 Join 으로 해
SELECT
	*
FROM
	T_ORD t1
	, (
		SELECT
			A.CUS_ID
		FROM T_ORD A
		WHERE
			A.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
			AND A.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
		GROUP BY A.CUS_ID
		HAVING COUNT(*) >= 4
	) t2
WHERE
	t1.CUS_ID = t2.CUS_ID
	AND t1.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
	AND t1.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
ORDER BY t1.ORD_SEQ;

-- where 절 상관 서브쿼리
-- 데이터의 존재여부를 파악할 때 자주 사용한다.
-- 3월에 주문이 한 건이라도 존재하는 고객 
SELECT
	*
FROM M_CUS t1
WHERE EXISTS (
	SELECT 
		*
	FROM T_ORD A
	WHERE
		A.CUS_ID = t1.CUS_ID 
		AND A.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
		AND A.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
)

-- 3월에 ITM_TP 이 ELEC 인 주문이 한 건이라도 존재하는 고객
SELECT 
	*
FROM M_CUS t1
WHERE EXISTS (
	SELECT 
		*
	FROM
		T_ORD A
		, T_ORD_DET B
		, M_ITM C
	WHERE 
		A.CUS_ID = t1.CUS_ID 
		AND A.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
		AND A.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
		AND A.ORD_SEQ = B.ORD_SEQ 
		AND B.ITM_ID = C.ITM_ID 
		AND C.ITM_TP = 'ELEC'
);

-- 전체 고객을 조회하는데, 3월에 주문내역이 있는지 칼럼에 표시
SELECT 
	t1.CUS_ID 
	, t1.CUS_NM 
	, CASE WHEN EXISTS (
		SELECT
			*
		FROM T_ORD A
		WHERE
			A.CUS_ID = t1.CUS_ID 
			AND A.ORD_DT >= TO_DATE('20170301', 'YYYYMMDD')
			AND A.ORD_DT < TO_DATE('20170401', 'YYYYMMDD')
	) THEN 'Y' ELSE 'N' END ORD_YN_03
FROM M_CUS t1
ORDER BY t1.CUS_ID;

-- outer join 을 이용하는 방법
SELECT
	t1.CUS_ID 
	, MAX(t1.CUS_NM)
	, CASE WHEN MAX(t2.CUS_ID) IS NULL THEN 'N' ELSE 'Y' END ORD_YN_03
FROM M_CUS t1, T_ORD t2
WHERE
	t1.CUS_ID = t2.CUS_ID (+)
	AND t2.ORD_DT(+) >= TO_DATE('20170301', 'YYYYMMDD')
	AND t2.ORD_DT(+) < TO_DATE('20170401', 'YYYYMMDD')
GROUP BY t1.CUS_ID
ORDER BY t1.CUS_ID


-- MERGE: 존재하지 않으면 Insert / 존재하면 Update
-- 테스트용 테이블
CREATE TABLE M_CUS_CUD_TEST AS
SELECT
	*
FROM M_CUS t1;
ALTER TABLE M_CUS_CUD_TEST ADD CONSTRAINT pk_m_cus_cud_test PRIMARY key(cus_id) USING INDEX;

-- 고객을 입력하거나 변경하는 PL/SQL
DECLARE v_EXISTS_YN varchar2(1);
BEGIN
	SELECT
		NVL(MAX('Y'), 'N')
	INTO v_EXISTS_YN
	FROM DUAL A
	WHERE EXISTS (
		SELECT
			*
		FROM M_CUS_CUD_TEST t1
		WHERE t1.CUS_ID = 'CUS_0090'
	);


	IF v_EXISTS_YN = 'N' THEN
		INSERT INTO M_CUS_CUD_TEST
			(CUS_ID, CUS_NM, CUS_GD)
		VALUES
			('CUS_0090', 'NAME_0090', 'A');
	ELSE
		UPDATE
			M_CUS_CUD_TEST t1
		SET
			t1.CUS_NM = 'NAME_0090'
			, t1.CUS_GD = 'A'
		WHERE CUS_ID = 'CUS_0090'
END;

-- merge 를 이용하여 한 번에 처리
-- merge 대상: update/insert 될 테이블, merge into 뒤에 쓴다.
-- merge 비교 대상: merge 대상의 처리 방법을 결정할 비교 데이터 집합, using 에 사용한다.
-- merge 비교 조건: on 뒤에 비교 조건을 적고, 조건이 일치하면 when matched then, 일치하지 않으면 when not matched then 에 동작을 써넣는다.
MERGE INTO M_CUS_CUD_TEST T1
USING (
	SELECT
		'CUS_00909' CUS_ID
		, 'NAME_0090' CUS_NM
		,'A' CUS_GD
	FROM DUAL
) t2
ON t1.CUS_ID = t2.CUS_ID
WHEN MATCHED THEN
	UPDATE
	SET
		t1.CUS_NM = t2.CUS_NM
		, t1.CUS_GD = t2.CUS_GD
WHEN NOT MATCHED THEN 
	INSERT
		(t1.CUS_ID, t1.CUS_NM, t1.CUS_GD)
	VALUES
		(t2.CUS_ID, t2.CUS_NM, t2.CUS_GD);
COMMIT;
-- MySql 의 Insert ~ ON Duplicate Key 는, 우선 insert 를 시도하고 키 중복 에러가 나면(PK/UniqueKey) update 를 시도한다.

-- Merge 를 이용한 Update: Not matched then 을 작성하지 않으면 update 만 시도한다.

-- 월별 고객주문 테이블 생성/데이터 입력
-- 17년 2월의 고객, 아이템 유형별 데이터가 입력된다.
-- ORD_QTY, ORD_AMT 가 모두 NULL 인데, update 하려면 T_ORD_DET 을 이용해야 한다.
CREATE TABLE S_CUS_YM (
 	BAS_YM varchar2(6) NOT NULL,
 	CUS_ID varchar2(40) NOT NULL,
 	ITM_TP varchar2(40) NOT NULL,
 	ORD_QTY number(18, 3) NULL,
 	ORD_AMT number(18, 3) null
 );
 CREATE UNIQUE INDEX pk_s_cus_ym ON s_cus_ym(bas_ym, cus_id, itm_tp);
 ALTER TABLE s_cus_ym ADD CONSTRAINT pk_s_cum_ym PRIMARY KEY (bas_ym, cus_id, itm_tp);
 INSERT INTO s_cus_ym (bas_ym, cus_id, itm_tp, ord_qty, ord_amt)
 SELECT
 	'201702' BAS_YM
 	, t1.CUS_ID
	, t2.BAS_CD
	, NULL ORD_QTY
	, NULL ORD_AMT
 FROM M_CUS t1, C_BAS_CD t2
 WHERE
 	t2.BAS_CD_DV = 'ITM_TP'
 	AND t2.LNG_CD = 'KO';
 COMMIT;

-- 기본 Update, 서브쿼리를 두 번 사용하여 성능상 좋지 못하다.
UPDATE S_CUS_YM t1
SET
	t1.ORD_QTY = (
		SELECT
			SUM(B.ORD_QTY)
		FROM
			T_ORD A
			, T_ORD_DET B
			, M_ITM C
		WHERE
			A.ORD_SEQ = B.ORD_SEQ
			AND B.ITM_ID = C.ITM_ID
			AND C.ITM_TP = t1.ITM_TP
			AND A.ORD_DT >= TO_DATE(t1.BAS_YM || '01', 'YYYYMMDD')
			AND A.ORD_DT < ADD_MONTHS(TO_DATE(t1.BAS_YM || '01', 'YYYYMMDD'), 1)
	)
	, t1.ORD_AMT = (
		SELECT
			SUM(B.ORD_QTY * B.UNT_PRC)
		FROM
			T_ORD A
			, T_ORD_DET B
			, M_ITM C
		WHERE 
			A.ORD_SEQ = B.ORD_SEQ
			AND B.ITM_ID = C.ITM_ID
			AND C.ITM_TP = t1.ITM_TP
			AND A.ORD_DT >= TO_DATE(t1.BAS_YM || '01', 'YYYYMMDD')
			AND A.ORD_DT < ADD_MONTHS(TO_DATE(t1.BAS_YM || '01', 'YYYYMMDD'), 1)
	)
WHERE t1.BAS_YM = '201702';

-- Merge 를 사용하여 서브쿼리 1회 사용하여 개선
-- 주문 실적이 발생한 데이터만 변경한다. 없는 데이터를 NULL 이 아니라 0으로 처리해야한다면 수정해야 한다.
MERGE INTO S_CUS_YM t1
USING (
	SELECT
		A.CUS_ID 
		, C.ITM_TP 
		, SUM(B.ORD_QTY) ORD_QTY
		, SUM(B.ORD_QTY * B.UNT_PRC) ORD_AMT
	FROM
		T_ORD A
		, T_ORD_DET B
		, M_ITM C
	WHERE 
		A.ORD_SEQ = B.ORD_SEQ
		AND B.ITM_ID = C.ITM_ID
		AND A.ORD_DT >= TO_DATE('201702' || '01', 'YYYYMMDD')
		AND A.ORD_DT < ADD_MONTHS(TO_DATE('201702' || '01', 'YYYYMMDD'), 1)
	GROUP BY A.CUS_ID, C.ITM_TP
) t2
ON (
	t1.BAS_YM = '201702'
	AND t1.CUS_ID = t2.CUS_ID
	AND t1.ITM_TP = t2.ITM_TP
)
WHEN MATCHED THEN UPDATE SET t1.ORD_QTY = t2.ORD_QTY, t1.ORD_AMT = t2.ORD_AMT;
COMMIT;

-- WITH: 인라인뷰와 비슷하지만, SQL 가장 윗부분에서 사용한다. 같은 SQL내에서 테이블처럼 사용할 수 있다.
-- 반복되는 인라인 뷰를 제거하여 성능개선을 하거나 가독성을 좋게 할 수 있다. 성능은 실행계획을 확인해야 정확히 알 수 있고, 무분별하게 사용하여 성능이 나빠질 수도 있다.
-- With 절마다 같은 테이블을 반복사용하는 것을 주의해야한다.
-- 고객, 아이템유형별 주문금액 구하기: 인라인뷰
SELECT
	t0.CUS_ID
	, t1.CUS_NM
	, t0.ITM_TP
	, (SELECT A.BAS_CD_NM FROM C_BAS_CD A WHERE A.LNG_CD='KO' AND A.BAS_CD_DV='ITM_TP' AND A.BAS_CD = t0.ITM_TP) ITM_TP_NM
	, t0.ORD_AMT
FROM (
	SELECT 
		A.CUS_ID
		, C.ITM_TP 
		, SUM(B.UNT_PRC * B.ORD_QTY) ORD_AMT
	FROM
		T_ORD A
		, T_ORD_DET B
		, M_ITM C
	WHERE
		A.ORD_SEQ  = B.ORD_SEQ 
		AND B.ITM_ID = C.ITM_ID
	GROUP BY A.CUS_ID, C.ITM_TP
	) t0
	, M_CUS t1
WHERE t0.CUS_ID = t1.CUS_ID
ORDER BY t0.CUS_ID, t0.ITM_TP;

-- 고객, 아이템유형별 주문금액 구하기: with 절 이용
WITH T_CUS_ITM_AMT AS (
	SELECT 
		A.CUS_ID
		, C.ITM_TP 
		, SUM(B.UNT_PRC * B.ORD_QTY) ORD_AMT
	FROM
		T_ORD A
		, T_ORD_DET B
		, M_ITM C
	WHERE
		A.ORD_SEQ  = B.ORD_SEQ 
		AND B.ITM_ID = C.ITM_ID
	GROUP BY A.CUS_ID, C.ITM_TP
)
SELECT
	t0.CUS_ID
	, t1.CUS_NM
	, t0.ITM_TP
	, (SELECT A.BAS_CD_NM FROM C_BAS_CD A WHERE A.LNG_CD='KO' AND A.BAS_CD_DV='ITM_TP' AND A.BAS_CD = t0.ITM_TP) ITM_TP_NM
	, t0.ORD_AMT
FROM
	T_CUS_ITM_AMT t0
	, M_CUS t1
WHERE t0.CUS_ID = t1.CUS_ID 
ORDER BY t0.CUS_ID, t0.ITM_TP;

-- 고객, 아이템 유형별 주문금액, 전체주문 대비 주문금액비율
WITH T_CUS_ITM_AMT AS (
	SELECT 
		A.CUS_ID
		, C.ITM_TP 
		, SUM(B.UNT_PRC * B.ORD_QTY) ORD_AMT
	FROM
		T_ORD A
		, T_ORD_DET B
		, M_ITM C
	WHERE
		A.ORD_SEQ  = B.ORD_SEQ 
		AND B.ITM_ID = C.ITM_ID
		AND A.ORD_DT >= TO_DATE('20170201', 'YYYYMMDD')
		AND A.ORD_DT < TO_DATE('20170301', 'YYYYMMDD')
	GROUP BY A.CUS_ID, C.ITM_TP
), T_TTL_AMT AS (
	SELECT 
		SUM(A.ORD_AMT) ORD_AMT 
	FROM T_CUS_ITM_AMT A
)
SELECT
	t0.CUS_ID
	, t1.CUS_NM
	, t0.ITM_TP
	, (SELECT A.BAS_CD_NM FROM C_BAS_CD A WHERE A.LNG_CD='KO' AND A.BAS_CD_DV='ITM_TP' AND A.BAS_CD = t0.ITM_TP) ITM_TP_NM
	, t0.ORD_AMT
	, ROUND(t0.ORD_AMT / t2.ORD_AMT * 100, 2) ORD_AMT_RT
FROM
	T_CUS_ITM_AMT t0
	, M_CUS t1
	, T_TTL_AMT t2
WHERE t0.CUS_ID = t1.CUS_ID 
ORDER BY t0.CUS_ID, t0.ITM_TP;

-- with 를 이용한 insert
-- 테스트용 S_CUS_YM 테이블에 ORD_AMT_RT 컬럼 추가
ALTER TABLE S_CUS_YM ADD ORD_AMT_RT number(18, 3);

INSERT INTO S_CUS_YM
	(
		BAS_YM
		, CUS_ID
		, ITM_TP
		, ORD_QTY
		, ORD_AMT
		, ORD_AMT_RT
	)
WITH T_CUS_ITM_AMT AS (
	SELECT 
		TO_CHAR(A.ORD_DT, 'YYYYMM') BAS_YM
		, A.CUS_ID
		, C.ITM_TP 
		, SUM(B.ORD_QTY) ORD_QTY
		, SUM(B.UNT_PRC * B.ORD_QTY) ORD_AMT
	FROM
		T_ORD A
		, T_ORD_DET B
		, M_ITM C
	WHERE
		A.ORD_SEQ  = B.ORD_SEQ 
		AND B.ITM_ID = C.ITM_ID
		AND A.ORD_DT >= TO_DATE('20170201', 'YYYYMMDD')
		AND A.ORD_DT < TO_DATE('20170301', 'YYYYMMDD')
	GROUP BY TO_CHAR(A.ORD_DT, 'YYYYMM'), A.CUS_ID, C.ITM_TP
), T_TTL_AMT AS (
	SELECT 
		SUM(A.ORD_AMT) ORD_AMT
	FROM T_CUS_ITM_AMT A
)
SELECT
	t0.BAS_YM
	, t0.CUS_ID
	, t0.ITM_TP
	, t0.ORD_QTY
	, t0.ORD_AMT
	, ROUND(t0.ORD_AMT / t2.ORD_AMT * 100, 2) ORD_AMT_RT
FROM
	T_CUS_ITM_AMT t0
	, M_CUS t1
	, T_TTL_AMT t2
WHERE t0.CUS_ID = t1.CUS_ID