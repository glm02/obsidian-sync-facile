@echo off
rem Faux GitHub CLI pour les tests : note ses arguments et simule la création du dépôt en local.
echo %*>> "%FAUX_GH_LOG%"
if "%1 %2"=="repo create" (
  git remote add origin "%FAUX_DISTANT%"
  git push -q -u origin main
  exit /b %ERRORLEVEL%
)
if "%1 %2"=="repo view" (
  echo test/coffre
  exit /b 0
)
exit /b 0
