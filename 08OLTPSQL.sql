----------------------------------------------------------------------------------------------------
-- 트랜잭션
----------------------------------------------------------------------------------------------------
-- 트랜잭션: 한 번에 처리되어야 하는 논리적인 작업 단위
-- commit: 트랜잭션 과정 중에 변경된 데이터를 모두 반영하고 종료
-- rollback: 트랜잭션 과정에서 진행된 작업을 모두 취소하고 종료

-- 테스트 테이블 생성
CREATE TABLE M_ACC (
	ACC_NO varchar2(40) NOT NULL,
	ACC_NM varchar2(100) NULL,
	BAL_AMT number(18,3) NULL
);
ALTER TABLE M_ACC ADD CONSTRAINT PK_M_ACC PRIMARY KEY (ACC_NO) USING INDEX;

INSERT INTO M_ACC(ACC_NO, ACC_NM, BAL_AMT)
SELECT 'ACC1', '1번계좌', 3000 FROM dual UNION ALL
SELECT 'ACC2', '2번계좌', 500 FROM dual UNION ALL
SELECT 'ACC3', '3번계좌', 0 FROM dual;

SELECT * FROM M_ACC;

-- ACC1 에서 ACC2 로 500원 이체
UPDATE M_ACC t1
SET t1.BAL_AMT = t1.BAL_AMT - 500
WHERE t1.ACC_NO = 'ACC1';

UPDATE M_ACC t1
SET t1.BAL_AMT = t1.BAL_AMT + 500
WHERE t1.ACC_NO = 'ACC2';

COMMIT;

-- ACC1 에서 ACC4(존재하지 않는 계좌)로 이체
UPDATE M_ACC t1
SET t1.BAL_AMT = t1.BAL_AMT - 500
WHERE t1.ACC_NO = 'ACC1';

UPDATE M_ACC t1
SET t1.BAL_AMT = t1.BAL_AMT + 500
WHERE t1.ACC_NO = 'ACC4';

SELECT * FROM M_ACC;
rollback;

-- 이체 금액이 잔액보다 큰 경우
UPDATE M_ACC t1
SET t1.BAL_AMT = t1.BAL_AMT - 5000
WHERE t1.ACC_NO = 'ACC1';

UPDATE M_ACC t1
SET t1.BAL_AMT = t1.BAL_AMT + 5000
WHERE t1.ACC_NO = 'ACC3';

SELECT * FROM M_ACC;
rollback;

-- 트랜잭션 중 에러가 발생한 경우, 에러가 발생했다고 해서 자동으로 rollback 되지 않는다.
INSERT INTO M_ACC(ACC_NO, ACC_NM, BAL_AMT) VALUES ('ACC4', '4번계좌', 0);
INSERT INTO M_ACC(ACC_NO, ACC_NM, BAL_AMT) VALUES ('ACC1', '1번계좌', 0); -- 이미 존재하므로 에러 발생

-- 고립화 수준
-- Read Uncommitted(오라클에서 제공하지 않음), Read Committed, Repeatable Read, Serializable Read

-- Read Committed: Update-Select 테스트


----------------------------------------------------------------------------------------------------
-- 첫 번째 세션이 Update 를 한 후에 트랜잭션을 종료하지 않아서, 두 번째 Session 의 Select 는 반영되기 전의 데이터를 조회한다.
----------------------------------------------------------------------------------------------------
-- Session 1: Update
UPDATE M_ACC t1
SET t1.BAL_AMT = 5000
WHERE t1.ACC_NO = 'ACC1';

COMMIT;
-- Session 2: Select
SELECT * FROM M_ACC t1 WHERE t1.ACC_NO = 'ACC1';

----------------------------------------------------------------------------------------------------
-- 첫 번째 세션이 Update 를 한 후에 트랜잭션을 종료하지 않아서, 두 번째 Update 는 대기하게 된다.
----------------------------------------------------------------------------------------------------
-- Session 1: Update
UPDATE M_ACC t1
SET t1.BAL_AMT = t1.BAL_AMT - 500
WHERE t1.ACC_NO = 'ACC1';
COMMIT;
-- Session 2: Update
UPDATE M_ACC t1
SET t1.BAL_AMT = t1.BAL_AMT - 500
WHERE t1.ACC_NO = 'ACC1';
COMMIT;

----------------------------------------------------------------------------------------------------
-- 같은 PK 값을 insert 하는 경우, 첫 번째 세션에 따라 두 번째 세션이 결정된다.
-- 첫 번째 insert 가 성공하여 commit 되면, 두 번째 insert 는 실패하게 된다.
-- 첫 번째 insert 가 rollback 되면, 두 번째 insert 는 성공하게 된다.
-- 따라서 첫 번째 트랜잭션이 종료될 때까지 대기하게 된다.
----------------------------------------------------------------------------------------------------
-- Session 1: Insert
INSERT INTO M_ACC(ACC_NO, ACC_NM, BAL_AMT) VALUES ('ACC4', '4번계좌', 0);
COMMIT;
ROLLBACK;
-- Session 2: Insert
INSERT INTO M_ACC(ACC_NO, ACC_NM, BAL_AMT) VALUES ('ACC4', '4번계좌', 0);
COMMIT;

DELETE FROM M_ACC WHERE ACC_NO = 'ACC4';
COMMIT;