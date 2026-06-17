-- Create main table
IF OBJECT_ID('T_RequestTouches', 'U') IS NOT NULL
  DROP TABLE T_RequestTouches;

IF OBJECT_ID('T_RequestWorkflow', 'U') IS NOT NULL
  DROP TABLE T_RequestWorkflow;

IF OBJECT_ID('T_Requests', 'U') IS NOT NULL
  DROP TABLE T_Requests;

CREATE TABLE T_Requests (
  Id INT PRIMARY KEY IDENTITY(1,1),
  CreatedDate DATETIME DEFAULT GETDATE()
);

CREATE TABLE T_RequestTouches (
  Id INT PRIMARY KEY IDENTITY(1,1),
  RequestId INT NOT NULL FOREIGN KEY REFERENCES T_Requests(Id),
  TouchType INT NOT NULL,
  CreatedDate DATETIME DEFAULT GETDATE()
);

CREATE TABLE T_RequestWorkflow (
  Id INT PRIMARY KEY IDENTITY(1,1),
  RequestId INT NOT NULL FOREIGN KEY REFERENCES T_Requests(Id),
  CreatedDate DATETIME DEFAULT GETDATE()
);

-- Workflow trigger: fires for touch_type IN (2, 8, 12)
-- This trigger generates an extra result set that breaks Rails 8 type casting
CREATE TRIGGER trg_RequestTouches_Workflow
ON T_RequestTouches
AFTER INSERT
AS
BEGIN
  -- Only fire for specific touch types that trigger workflow
  IF EXISTS (SELECT 1 FROM inserted WHERE TouchType IN (2, 8, 12))
  BEGIN
    -- Emit a single-column result set to mimic trigger-side extra results
    -- seen in production workflows.
    SELECT CAST(1 AS BIGINT) AS TriggerResult

    INSERT INTO T_RequestWorkflow (RequestId)
    SELECT DISTINCT RequestId FROM inserted WHERE TouchType IN (2, 8, 12)
  END
END;
