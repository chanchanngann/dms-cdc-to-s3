
-- insert
INSERT INTO test_dms123 (name) VALUES ('Rachel');

-- update
UPDATE test_dms123
SET name = 'Alice_updated'
WHERE name = 'Alice';

-- delete
DELETE FROM test_dms123 WHERE name = 'Bob';