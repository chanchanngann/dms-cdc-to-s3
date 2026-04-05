CREATE TABLE test_dms123 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    updated_at TIMESTAMP DEFAULT NOW()
);


INSERT INTO test_dms123 (name) VALUES
('Alice'),
('Bob'),
('Charlie');