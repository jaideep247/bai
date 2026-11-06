# ABAP Health Check System

A flexible, design pattern-based health check system for SAP ABAP that supports dynamic configuration with multiple execution types including class/method, function module, and custom table-based rule execution.

## Features

- **Flexible Execution Types**: Support for class/method, function module, SQL, and table-based rule execution
- **Design Patterns**: Implements Strategy, Factory, and Orchestrator patterns for maintainable code
- **Dynamic Configuration**: Rule-based configuration stored in custom tables
- **Process Mapping**: End-to-end process health monitoring with step-by-step execution
- **Alerting System**: Configurable alerts for different notification channels
- **KPI Monitoring**: Built-in KPI calculation and threshold monitoring
- **Enterprise Grade**: Scalable, maintainable, and production-ready

## Architecture

### Core Components

1. **Data Dictionary Structures** (`zhealth_check_structures.abap`)
   - Custom tables for process, step, rule, execution, alert, and KPI definitions
   - Interface and class definitions for strategy pattern implementation

2. **Strategy Pattern Implementations**
   - `ZCL_HEALTH_CHECK_CLASS_EXECUTOR`: Executes class/method based health checks
   - `ZCL_HEALTH_CHECK_FUNCTION_EXECUTOR`: Executes function module based health checks
   - `ZCL_HEALTH_CHECK_TABLE_EXECUTOR`: Executes table-based rule health checks
   - `ZCL_HEALTH_CHECK_SQL_EXECUTOR`: Executes SQL-based health checks

3. **Factory Pattern** (`ZCL_HEALTH_CHECK_FACTORY`)
   - Creates appropriate executor instances based on execution type

4. **Orchestrator** (`ZCL_HEALTH_CHECK_ORCHESTRATOR`)
   - Main controller for executing processes and steps
   - Handles error management, retries, and result aggregation

5. **Configuration Management** (`ZHEALTH_CHECK_CONFIG`)
   - Program for managing health check configurations
   - CRUD operations for processes, steps, rules, alerts, and KPIs

6. **Main Execution Program** (`ZHEALTH_CHECK_MAIN`)
   - Main program for executing health checks
   - Supports both single step and full process execution

## Installation

1. **Create Custom Tables**
   ```sql
   -- Create tables based on structures in zhealth_check_structures.abap
   CREATE TABLE zthc_process (process_id CHAR(32) PRIMARY KEY, ...);
   CREATE TABLE zthc_step (step_id CHAR(32) PRIMARY KEY, ...);
   CREATE TABLE zthc_rule (rule_id CHAR(32) PRIMARY KEY, ...);
   CREATE TABLE zthc_execution (execution_id CHAR(32) PRIMARY KEY, ...);
   CREATE TABLE zthc_alert (alert_id CHAR(32) PRIMARY KEY, ...);
   CREATE TABLE zthc_kpi (kpi_id CHAR(32) PRIMARY KEY, ...);
   ```

2. **Import ABAP Classes**
   - Import all class files from the `classes/` directory
   - Activate all classes and interfaces

3. **Import Programs**
   - Import `ZHEALTH_CHECK_MAIN` and `ZHEALTH_CHECK_CONFIG` programs
   - Activate programs

## Usage

### 1. Configuration

Use the `ZHEALTH_CHECK_CONFIG` program to create health check configurations:

```abap
" Create a new process
p_action = 'CREATE_PROCESS'
p_procid = 'DB_HEALTH_CHECK'
p_name = 'Database Health Check'
p_desc = 'Comprehensive database health monitoring'

" Create a step with class/method execution
p_action = 'CREATE_STEP'
p_procid = 'DB_HEALTH_CHECK'
p_stepid = 'DB_CONN_CHECK'
p_name = 'Database Connection Check'
p_type = 'CLASS'
p_ref = 'ZCL_DB_MONITOR/CHECK_CONNECTION'
p_params = '{"timeout": 30, "retry_count": 3}'

" Create a step with function module execution
p_action = 'CREATE_STEP'
p_procid = 'DB_HEALTH_CHECK'
p_stepid = 'TABLESPACE_CHECK'
p_name = 'Table Space Usage Check'
p_type = 'FUNC'
p_ref = 'Z_GET_TABLESPACE_USAGE'
p_params = '{"warning_threshold": 80}'

" Create a step with SQL execution
p_action = 'CREATE_STEP'
p_procid = 'DB_HEALTH_CHECK'
p_stepid = 'LONG_QUERY_CHECK'
p_name = 'Long Running Query Check'
p_type = 'SQL'
p_ref = 'SELECT COUNT(*) FROM V$SESSION WHERE STATUS = "ACTIVE" AND LAST_CALL_ET > 300'
p_params = '{"max_duration_minutes": 30}'

" Create a step with table-based rules
p_action = 'CREATE_STEP'
p_procid = 'DB_HEALTH_CHECK'
p_stepid = 'DB_LOCK_CHECK'
p_name = 'Database Lock Check'
p_type = 'TABLE'
p_ref = 'ZTHC_DB_LOCKS'
p_params = '{"max_lock_duration": 300}'

" Create rules for table-based step
p_action = 'CREATE_RULE'
p_stepid = 'DB_LOCK_CHECK'
p_type = 'SQL'
p_params = 'LOCK_DURATION > 300'
p_ref = 'CRITICAL: Long running locks detected'
```

### 2. Execution

Use the `ZHEALTH_CHECK_MAIN` program to execute health checks:

```abap
" Execute entire process
p_procid = 'DB_HEALTH_CHECK'
p_exec = 'X'

" Execute single step
p_stepid = 'DB_CONN_CHECK'
p_exec = 'X'
```

### 3. Monitoring

The system automatically:
- Logs all executions in `ZTHC_EXECUTION` table
- Calculates KPIs based on execution results
- Triggers alerts based on configured conditions
- Provides detailed error information and stack traces

## Execution Types

### 1. Class/Method Execution (`CLASS`)
- Executes methods from ABAP classes
- Format: `CLASS_NAME/METHOD_NAME`
- Parameters passed as JSON string
- Supports both static and instance methods

### 2. Function Module Execution (`FUNC`)
- Executes ABAP function modules
- Parameters passed as JSON string
- Handles function module exceptions
- Supports both RFC and local function modules

### 3. SQL Execution (`SQL`)
- Executes SQL queries dynamically
- Supports parameter replacement
- Returns row count and result data
- Can be used for database health checks

### 4. Table-based Rules (`TABLE`)
- Executes rules stored in custom tables
- Supports SQL, ABAP, and custom rule types
- Rules are evaluated in order
- Supports complex business logic

## Configuration Examples

### Database Health Check
```abap
Process: DB_HEALTH_CHECK
├── Step 1: DB_CONN_CHECK (CLASS) - Check database connectivity
├── Step 2: TABLESPACE_CHECK (SQL) - Check table space usage
├── Step 3: LONG_QUERY_CHECK (CLASS) - Check long running queries
└── Step 4: DB_LOCK_CHECK (TABLE) - Check database locks
```

### Application Health Check
```abap
Process: APP_HEALTH_CHECK
├── Step 1: USER_SESSION_CHECK (FUNC) - Check active sessions
├── Step 2: MEMORY_CHECK (CLASS) - Check memory usage
└── Step 3: BG_JOB_CHECK (SQL) - Check background jobs
```

### Business Process Health Check
```abap
Process: BUSINESS_HEALTH_CHECK
├── Step 1: ORDER_PROCESS_CHECK (CLASS) - Check order processing
└── Step 2: DATA_CONSISTENCY_CHECK (TABLE) - Check data consistency
```

## Alerting

Configure alerts for different notification channels:

```abap
" Email alert
p_action = 'CREATE_ALERT'
p_procid = 'DB_HEALTH_CHECK'
p_stepid = 'DB_CONN_CHECK'
p_type = 'EMAIL'
p_params = 'status = "ERROR"'
p_ref = '["admin@company.com", "dba@company.com"]'

" Slack alert
p_action = 'CREATE_ALERT'
p_procid = 'APP_HEALTH_CHECK'
p_stepid = 'MEMORY_CHECK'
p_type = 'SLACK'
p_params = 'status = "WARNING"'
p_ref = '["#alerts", "#ops-team"]'
```

## KPI Monitoring

Define KPIs for process monitoring:

```abap
" Response time KPI
p_action = 'CREATE_KPI'
p_procid = 'DB_HEALTH_CHECK'
p_name = 'Database Response Time'
p_type = 'DURATION'
p_params = 'average(response_time)'
p_ref = '{"warning": 1000, "critical": 5000}'

" Success rate KPI
p_action = 'CREATE_KPI'
p_procid = 'APP_HEALTH_CHECK'
p_name = 'Success Rate'
p_type = 'PERCENTAGE'
p_params = 'success_count / total_count * 100'
p_ref = '{"warning": 95, "critical": 90}'
```

## Error Handling

The system provides comprehensive error handling:
- Custom exception class `ZCX_HEALTH_CHECK_ERROR`
- Detailed error messages and stack traces
- Automatic retry mechanism for failed steps
- Graceful degradation for non-critical failures

## Performance Considerations

- Asynchronous execution support
- Configurable timeouts and retry counts
- Efficient database queries with proper indexing
- Minimal memory footprint for large-scale deployments

## Security

- Role-based access control for configuration management
- Secure parameter passing for external function calls
- Audit logging for all configuration changes
- Input validation and sanitization

## Extensibility

The system is designed for easy extension:
- Add new execution types by implementing the `ZIF_HEALTH_CHECK_EXECUTOR` interface
- Add new rule types in the table executor
- Add new alert channels by extending the alert system
- Add new KPI types by extending the KPI calculation logic

## Troubleshooting

Common issues and solutions:

1. **Step execution fails**: Check the execution reference and parameters
2. **Rules not evaluating**: Verify rule conditions and table data
3. **Alerts not triggering**: Check alert conditions and recipient configuration
4. **Performance issues**: Review step timeouts and retry counts

## Support

For technical support and questions:
- Check the example configurations in `examples/example_configuration.abap`
- Review the execution logs in `ZTHC_EXECUTION` table
- Use the configuration management program for troubleshooting
