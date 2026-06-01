@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM  CONSTANTS
REM ============================================================
set "ORG_ALIAS=coffee-dev1"
set "TEMP_DEPLOY=temp_deploy"
set "TEMP_RT_FOLDER=%TEMP_DEPLOY%\main\default\objects\Account\recordTypes"
set "TEMP_PS_FOLDER=%TEMP_DEPLOY%\main\default\permissionsets"
set "TEMP_PROFILE_FOLDER=%TEMP_DEPLOY%\main\default\profiles"

REM Site / Experience Cloud
set "SITE_NAME=Customer Portal"
set "SITE_TEMPLATE=Customer Account Portal"
set "SITE_URL_PATH=customerportal"

REM Account Record Types (business only — Person Account "Customer" RT deploys with metadata after PA is enabled)
set "RT_COUNT=4"

set "RT_API_1=Agency"
set "RT_LABEL_1=Agency"
set "RT_DESC_1=Capture Agencies"

set "RT_API_2=Agency_B2B"
set "RT_LABEL_2=Agency B2B"
set "RT_DESC_2="

set "RT_API_3=Carrier"
set "RT_LABEL_3=Carrier"
set "RT_DESC_3=Capture Insurance companies"

set "RT_API_4=Carrier_B2B"
set "RT_LABEL_4=Carrier B2B"
set "RT_DESC_4="

REM Permission Sets
set "PS_COUNT=2"
set "PS_API_1=Customer_Portal_Admin"
set "PS_LABEL_1=Customer Portal Admin"
set "PS_DESC_1=Admin access for Customer Portal users"

set "PS_API_2=Customer_Portal_User"
set "PS_LABEL_2=Customer Portal User"
set "PS_DESC_2=Standard access for Customer Portal users"

REM Profiles
set "PROFILE_COUNT=2"
set "PROFILE_API_1=Customer Portal User"
set "PROFILE_LICENSE_1=Customer Community Plus Login"

set "PROFILE_API_2=Covu Admin"
set "PROFILE_LICENSE_2=Salesforce"

echo.
echo ============================================================
echo   Init Setup Org
echo   Target org: %ORG_ALIAS%
echo ============================================================
echo.

REM ============================================================
REM  STEP 1: Enable Digital Experiences
REM ============================================================
echo [Step 1/8] Checking Digital Experiences...

call sf data query -o %ORG_ALIAS% -q "SELECT COUNT() FROM Network" >nul 2>&1
if errorlevel 1 (
  echo   Not enabled. Enabling now...
  if not exist "force-app\main\default\settings" mkdir "force-app\main\default\settings"
  set "COMM_FILE=force-app\main\default\settings\Communities.settings-meta.xml"
  (
    echo ^<?xml version="1.0" encoding="UTF-8"?^>
    echo ^<CommunitiesSettings xmlns="http://soap.sforce.com/2006/04/metadata"^>
    echo     ^<enableNetworksEnabled^>true^</enableNetworksEnabled^>
    echo ^</CommunitiesSettings^>
  ) > "!COMM_FILE!"
  call sf project deploy start -o %ORG_ALIAS% -d "!COMM_FILE!"
  if errorlevel 1 ( echo   [X] STEP 1 FAILED & pause & exit /b 1 )
  echo   [OK] STEP 1 COMPLETE - Digital Experiences enabled
) else (
  echo   [SKIP] STEP 1 - Already enabled
)
echo.

REM ============================================================
REM  STEP 2: Enable ExperienceBundle Metadata API
REM ============================================================
echo [Step 2/8] Checking ExperienceBundle Metadata API...

set "EB_FILE=force-app\main\default\settings\ExperienceBundle.settings-meta.xml"

if exist "%EB_FILE%" (
  echo   [SKIP] STEP 2 - Settings file already exists, assumed enabled
) else (
  echo   Settings file missing. Creating and deploying...
  (
    echo ^<?xml version="1.0" encoding="UTF-8"?^>
    echo ^<ExperienceBundleSettings xmlns="http://soap.sforce.com/2006/04/metadata"^>
    echo     ^<enableExperienceBundleMetadata^>true^</enableExperienceBundleMetadata^>
    echo ^</ExperienceBundleSettings^>
  ) > "%EB_FILE%"
  call sf project deploy start -o %ORG_ALIAS% -d "%EB_FILE%"
  if errorlevel 1 ( echo   [X] STEP 2 FAILED & pause & exit /b 1 )
  echo   [OK] STEP 2 COMPLETE - ExperienceBundle Metadata API enabled
)
echo.

REM ============================================================
REM  STEP 3: Customer Portal site
REM ============================================================
echo [Step 3/8] Checking %SITE_NAME% site...

call sf data query -o %ORG_ALIAS% -q "SELECT COUNT() FROM Network WHERE Name='%SITE_NAME%'" --json > site_check.json 2>nul
powershell -NoProfile -Command "try { $j = Get-Content -Raw site_check.json | ConvertFrom-Json; if ($j.result.totalSize -gt 0) { exit 0 } else { exit 1 } } catch { exit 1 }"
set "SITE_EXISTS=!errorlevel!"
del site_check.json >nul 2>&1

if "!SITE_EXISTS!"=="0" (
  echo   [SKIP] STEP 3 - %SITE_NAME% already exists
) else (
  echo   Creating %SITE_NAME%...
  call sf community create --name "%SITE_NAME%" --template-name "%SITE_TEMPLATE%" --url-path-prefix "%SITE_URL_PATH%" --target-org %ORG_ALIAS%
  if errorlevel 1 ( echo   [X] STEP 3 FAILED & pause & exit /b 1 )
  echo   [OK] STEP 3 COMPLETE - %SITE_NAME% queued for creation
)
echo.

REM ============================================================
REM  STEP 4: Account Record Types
REM ============================================================
echo [Step 4/8] Account record types...

echo   Querying existing record types...
call sf data query -o %ORG_ALIAS% -q "SELECT DeveloperName FROM RecordType WHERE SobjectType='Account'" --json > rt_existing.json 2>nul
powershell -NoProfile -Command "try { $j = Get-Content -Raw rt_existing.json | ConvertFrom-Json; $names = @($j.result.records | ForEach-Object { $_.DeveloperName }); ($names -join ',') | Out-File -Encoding ASCII -NoNewline rt_existing.txt } catch { '' | Out-File -Encoding ASCII -NoNewline rt_existing.txt }"
set "EXISTING_RTS="
if exist rt_existing.txt set /p EXISTING_RTS=<rt_existing.txt
del rt_existing.json rt_existing.txt >nul 2>&1

if "!EXISTING_RTS!"=="" (
  echo   No existing Account RTs in org.
  set "EXISTING_LIST=,,"
) else (
  echo   Existing: !EXISTING_RTS!
  set "EXISTING_LIST=,!EXISTING_RTS!,"
)
echo.

if exist "%TEMP_DEPLOY%" rmdir /s /q "%TEMP_DEPLOY%"
mkdir "%TEMP_RT_FOLDER%"
set "DEPLOY_NEEDED=0"

for /L %%i in (1,1,%RT_COUNT%) do call :ProcessRT %%i

if "!DEPLOY_NEEDED!"=="0" (
  echo   [SKIP] STEP 4 - All record types already exist
  rmdir /s /q "%TEMP_DEPLOY%" >nul 2>&1
) else (
  echo.
  echo   Deploying !DEPLOY_NEEDED! record type^(s^)...
  call sf project deploy start -o %ORG_ALIAS% -d "%TEMP_RT_FOLDER%"
  set "DEPLOY_RESULT=!errorlevel!"
  rmdir /s /q "%TEMP_DEPLOY%" >nul 2>&1
  if not "!DEPLOY_RESULT!"=="0" ( echo   [X] STEP 4 FAILED & pause & exit /b 1 )
  echo   [OK] STEP 4 COMPLETE - Account record types deployed
)
echo.

REM ============================================================
REM  STEP 5: Permission Sets
REM ============================================================
echo [Step 5/8] Permission Sets...

echo   Querying existing permission sets...
call sf data query -o %ORG_ALIAS% -q "SELECT Name FROM PermissionSet WHERE Name IN ('Customer_Portal_Admin','Customer_Portal_User')" --json > ps_existing.json 2>nul
powershell -NoProfile -Command "try { $j = Get-Content -Raw ps_existing.json | ConvertFrom-Json; $names = @($j.result.records | ForEach-Object { $_.Name }); ($names -join ',') | Out-File -Encoding ASCII -NoNewline ps_existing.txt } catch { '' | Out-File -Encoding ASCII -NoNewline ps_existing.txt }"
set "EXISTING_PS="
if exist ps_existing.txt set /p EXISTING_PS=<ps_existing.txt
del ps_existing.json ps_existing.txt >nul 2>&1

if "!EXISTING_PS!"=="" (
  set "PS_EXISTING_LIST=,,"
) else (
  echo   Existing: !EXISTING_PS!
  set "PS_EXISTING_LIST=,!EXISTING_PS!,"
)

if exist "%TEMP_DEPLOY%" rmdir /s /q "%TEMP_DEPLOY%"
mkdir "%TEMP_PS_FOLDER%"
set "PS_DEPLOY_NEEDED=0"

for /L %%i in (1,1,%PS_COUNT%) do call :ProcessPS %%i

if "!PS_DEPLOY_NEEDED!"=="0" (
  echo   [SKIP] STEP 5 - All permission sets already exist
  rmdir /s /q "%TEMP_DEPLOY%" >nul 2>&1
) else (
  echo.
  echo   Deploying !PS_DEPLOY_NEEDED! permission set^(s^)...
  call sf project deploy start -o %ORG_ALIAS% -d "%TEMP_PS_FOLDER%"
  set "DEPLOY_RESULT=!errorlevel!"
  rmdir /s /q "%TEMP_DEPLOY%" >nul 2>&1
  if not "!DEPLOY_RESULT!"=="0" ( echo   [X] STEP 5 FAILED & pause & exit /b 1 )
  echo   [OK] STEP 5 COMPLETE - Permission sets deployed
)
echo.

REM ============================================================
REM  STEP 6: Profiles
REM ============================================================
echo [Step 6/8] Profiles...

echo   Querying existing profiles...
call sf data query -o %ORG_ALIAS% -q "SELECT Name FROM Profile WHERE Name IN ('Customer Portal User','Covu Admin')" --json > prof_existing.json 2>nul
powershell -NoProfile -Command "try { $j = Get-Content -Raw prof_existing.json | ConvertFrom-Json; $names = @($j.result.records | ForEach-Object { $_.Name }); ($names -join '~') | Out-File -Encoding ASCII -NoNewline prof_existing.txt } catch { '' | Out-File -Encoding ASCII -NoNewline prof_existing.txt }"
set "EXISTING_PROFILES="
if exist prof_existing.txt set /p EXISTING_PROFILES=<prof_existing.txt
del prof_existing.json prof_existing.txt >nul 2>&1

if "!EXISTING_PROFILES!"=="" (
  set "PROFILE_EXISTING_LIST=~~"
) else (
  echo   Existing: !EXISTING_PROFILES!
  set "PROFILE_EXISTING_LIST=~!EXISTING_PROFILES!~"
)

if exist "%TEMP_DEPLOY%" rmdir /s /q "%TEMP_DEPLOY%"
mkdir "%TEMP_PROFILE_FOLDER%"
set "PROFILE_DEPLOY_NEEDED=0"

for /L %%i in (1,1,%PROFILE_COUNT%) do call :ProcessProfile %%i

if "!PROFILE_DEPLOY_NEEDED!"=="0" (
  echo   [SKIP] STEP 6 - All profiles already exist
  rmdir /s /q "%TEMP_DEPLOY%" >nul 2>&1
) else (
  echo.
  echo   Deploying !PROFILE_DEPLOY_NEEDED! profile^(s^)...
  call sf project deploy start -o %ORG_ALIAS% -d "%TEMP_PROFILE_FOLDER%"
  set "DEPLOY_RESULT=!errorlevel!"
  rmdir /s /q "%TEMP_DEPLOY%" >nul 2>&1
  if not "!DEPLOY_RESULT!"=="0" (
    echo   [X] STEP 6 FAILED - profile deploy errors above
    echo       Continuing to permset assignment...
  ) else (
    echo   [OK] STEP 6 COMPLETE - Profiles deployed
  )
)
echo.

REM ============================================================
REM  STEP 7: Assign Permission Sets to running user
REM ============================================================
echo [Step 7/8] Assigning permission sets to running user...

call sf org display -o %ORG_ALIAS% --json > org_info.json 2>nul
powershell -NoProfile -Command "try { $j = Get-Content -Raw org_info.json | ConvertFrom-Json; $j.result.username | Out-File -Encoding ASCII -NoNewline me.txt } catch { '' | Out-File -Encoding ASCII -NoNewline me.txt }"
set "MY_USERNAME="
if exist me.txt set /p MY_USERNAME=<me.txt
del org_info.json me.txt >nul 2>&1

set "MY_USER_ID="
if not "!MY_USERNAME!"=="" (
  call sf data query -o %ORG_ALIAS% -q "SELECT Id FROM User WHERE Username='!MY_USERNAME!'" --json > me.json 2>nul
  powershell -NoProfile -Command "try { $j = Get-Content -Raw me.json | ConvertFrom-Json; $j.result.records[0].Id | Out-File -Encoding ASCII -NoNewline me.txt } catch { '' | Out-File -Encoding ASCII -NoNewline me.txt }"
  if exist me.txt set /p MY_USER_ID=<me.txt
  del me.json me.txt >nul 2>&1
)

if "!MY_USER_ID!"=="" (
  echo   [X] Could not determine current user Id. Skipping assignment.
) else (
  echo   Running user: !MY_USERNAME!
  call :AssignPermset Customer_Portal_Admin !MY_USER_ID!
  call :AssignPermset Customer_Portal_User !MY_USER_ID!
)
echo.

REM ============================================================
REM  STEP 8: Person Accounts (manual - final step)
REM ============================================================
echo [Step 8/8] Checking Person Accounts...

call sf data query -o %ORG_ALIAS% -q "SELECT IsPersonAccount FROM Account LIMIT 1" >nul 2>&1
if not errorlevel 1 (
  echo   [SKIP] STEP 8 - Person Accounts already enabled
) else (
  call :PrintPersonAccountInstructions
)
echo.

echo ============================================================
echo   ALL DONE
echo ============================================================
pause
endlocal
exit /b 0

REM ============================================================
REM  SUBROUTINE: PrintPersonAccountInstructions
REM ============================================================
:PrintPersonAccountInstructions
setlocal DisableDelayedExpansion
echo   [X] Person Accounts is NOT enabled - MANUAL STEP REQUIRED
echo.
echo   To enable Person Accounts:
echo     1. Go to Setup -^> Person Accounts (Quick Find)
echo     2. Click "Check Readiness" button
echo     3. Wait for the readiness report (can take a minute)
echo     4. Click the link to enable Person Accounts
echo     5. Confirm the irreversible change in the dialog
echo.
echo   After enabling, re-run this script to verify.
endlocal
goto :eof

REM ============================================================
REM  SUBROUTINE: ProcessRT
REM ============================================================
:ProcessRT
setlocal EnableDelayedExpansion
set "IDX=%~1"
call set "RT_API=%%RT_API_%IDX%%%"
call set "RT_LABEL=%%RT_LABEL_%IDX%%%"
call set "RT_DESC=%%RT_DESC_%IDX%%%"
set "RT_FILE=%TEMP_RT_FOLDER%\!RT_API!.recordType-meta.xml"

echo !EXISTING_LIST! | findstr /C:",!RT_API!," >nul
if not errorlevel 1 (
  echo   - [SKIP] !RT_API! - already exists in org
  endlocal
  goto :eof
)

echo   - !RT_API! - writing minimal RT file...
call :WriteRTFile "!RT_FILE!" "!RT_API!" "!RT_LABEL!" "!RT_DESC!"

endlocal
set /a DEPLOY_NEEDED+=1
goto :eof

REM ============================================================
REM  SUBROUTINE: ProcessPS
REM ============================================================
:ProcessPS
setlocal EnableDelayedExpansion
set "IDX=%~1"
call set "PS_API=%%PS_API_%IDX%%%"
call set "PS_LABEL=%%PS_LABEL_%IDX%%%"
call set "PS_DESC=%%PS_DESC_%IDX%%%"
set "PS_FILE=%TEMP_PS_FOLDER%\!PS_API!.permissionset-meta.xml"

echo !PS_EXISTING_LIST! | findstr /C:",!PS_API!," >nul
if not errorlevel 1 (
  echo   - [SKIP] !PS_API! - already exists in org
  endlocal
  goto :eof
)

echo   - !PS_API! - writing permset file...
call :WritePSFile "!PS_FILE!" "!PS_LABEL!" "!PS_DESC!"

endlocal
set /a PS_DEPLOY_NEEDED+=1
goto :eof

REM ============================================================
REM  SUBROUTINE: ProcessProfile
REM ============================================================
:ProcessProfile
setlocal EnableDelayedExpansion
set "IDX=%~1"
call set "PROFILE_API=%%PROFILE_API_%IDX%%%"
call set "PROFILE_LICENSE=%%PROFILE_LICENSE_%IDX%%%"
set "PROFILE_FILE=%TEMP_PROFILE_FOLDER%\!PROFILE_API!.profile-meta.xml"

echo !PROFILE_EXISTING_LIST! | findstr /C:"~!PROFILE_API!~" >nul
if not errorlevel 1 (
  echo   - [SKIP] !PROFILE_API! - already exists in org
  endlocal
  goto :eof
)

echo   - !PROFILE_API! - writing minimal profile (license: !PROFILE_LICENSE!)...
call :WriteProfileFile "!PROFILE_FILE!" "!PROFILE_LICENSE!"

endlocal
set /a PROFILE_DEPLOY_NEEDED+=1
goto :eof

REM ============================================================
REM  SUBROUTINE: AssignPermset
REM  Args: %1=permset name  %2=user Id
REM ============================================================
:AssignPermset
set "PS_NAME=%~1"
set "USER_ID=%~2"

call sf data query -o %ORG_ALIAS% -q "SELECT Id FROM PermissionSetAssignment WHERE AssigneeId='%USER_ID%' AND PermissionSet.Name='%PS_NAME%'" --json > assign_check.json 2>nul
powershell -NoProfile -Command "try { $j = Get-Content -Raw assign_check.json | ConvertFrom-Json; if ($j.result.totalSize -gt 0) { exit 0 } else { exit 1 } } catch { exit 1 }"
set "ALREADY_ASSIGNED=%errorlevel%"
del assign_check.json >nul 2>&1

if "%ALREADY_ASSIGNED%"=="0" (
  echo   - [SKIP] %PS_NAME% - already assigned
  goto :eof
)

echo   - Assigning %PS_NAME%...
call sf org assign permset --name %PS_NAME% --target-org %ORG_ALIAS% --json >assign_out.json 2>&1
powershell -NoProfile -Command "try { $j = Get-Content -Raw assign_out.json | ConvertFrom-Json; if ($j.status -eq 0) { exit 0 } else { exit 1 } } catch { exit 1 }"
set "ASSIGN_RESULT=%errorlevel%"
del assign_out.json >nul 2>&1

if "%ASSIGN_RESULT%"=="0" (
  echo     [OK] %PS_NAME% assigned
) else (
  echo     [X] %PS_NAME% assignment failed
)
goto :eof

REM ============================================================
REM  SUBROUTINE: WriteRTFile
REM ============================================================
:WriteRTFile
set "WF_FILE=%~1"
set "WF_FULLNAME=%~2"
set "WF_LABEL=%~3"
set "WF_DESC=%~4"

> "%WF_FILE%" echo ^<?xml version="1.0" encoding="UTF-8"?^>
>> "%WF_FILE%" echo ^<RecordType xmlns="http://soap.sforce.com/2006/04/metadata"^>
>> "%WF_FILE%" echo     ^<fullName^>%WF_FULLNAME%^</fullName^>
>> "%WF_FILE%" echo     ^<active^>true^</active^>
if not "%WF_DESC%"=="" >> "%WF_FILE%" echo     ^<description^>%WF_DESC%^</description^>
>> "%WF_FILE%" echo     ^<label^>%WF_LABEL%^</label^>
>> "%WF_FILE%" echo ^</RecordType^>
goto :eof

REM ============================================================
REM  SUBROUTINE: WritePSFile
REM ============================================================
:WritePSFile
set "PSF_FILE=%~1"
set "PSF_LABEL=%~2"
set "PSF_DESC=%~3"

> "%PSF_FILE%" echo ^<?xml version="1.0" encoding="UTF-8"?^>
>> "%PSF_FILE%" echo ^<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata"^>
>> "%PSF_FILE%" echo     ^<hasActivationRequired^>false^</hasActivationRequired^>
>> "%PSF_FILE%" echo     ^<label^>%PSF_LABEL%^</label^>
if not "%PSF_DESC%"=="" >> "%PSF_FILE%" echo     ^<description^>%PSF_DESC%^</description^>
>> "%PSF_FILE%" echo ^</PermissionSet^>
goto :eof

REM ============================================================
REM  SUBROUTINE: WriteProfileFile
REM ============================================================
:WriteProfileFile
set "PRF_FILE=%~1"
set "PRF_LICENSE=%~2"

> "%PRF_FILE%" echo ^<?xml version="1.0" encoding="UTF-8"?^>
>> "%PRF_FILE%" echo ^<Profile xmlns="http://soap.sforce.com/2006/04/metadata"^>
>> "%PRF_FILE%" echo     ^<custom^>true^</custom^>
>> "%PRF_FILE%" echo     ^<userLicense^>%PRF_LICENSE%^</userLicense^>
>> "%PRF_FILE%" echo ^</Profile^>
goto :eof