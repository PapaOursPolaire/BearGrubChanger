@echo off
setlocal enabledelayedexpansion

:: Création du fichier select-file.ps1 dans le dossier courant
(
echo Add-Type -AssemblyName System.Windows.Forms
echo $ofd = New-Object System.Windows.Forms.OpenFileDialog
echo $ofd.Filter = "GIF et Video (*.gif;*.mp4)|*.gif;*.mp4"
echo if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
echo^    $ofd.FileName ^| Out-File -Encoding utf8 selected-file.txt
echo } else {
echo^    "" ^| Out-File -Encoding utf8 selected-file.txt
echo }
) > select-file.ps1

:: Vérifier que ffmpeg est installé
ffmpeg -version >nul 2>&1
if errorlevel 1 (
    echo ERREUR : ffmpeg n'est pas installe ou pas dans le PATH.
    pause
    exit /b 1
)

:: Lancer le script PowerShell pour sélectionner le fichier
powershell -NoProfile -ExecutionPolicy Bypass -File select-file.ps1

:: Lire la sélection
set "file="
if exist selected-file.txt (
    set /p file=<selected-file.txt
    del selected-file.txt
) else (
    echo ERREUR : impossible de recuperer la selection.
    pause
    exit /b 1
)

if "%file%"=="" (
    echo Aucune selection de fichier. Fin du script.
    pause
    exit /b 1
)

echo Fichier selectionne : %file%

:: Création dossier de sortie
set "outdir=plymouth_output"
if not exist "%outdir%" mkdir "%outdir%"
cd /d "%outdir%"

:: Extraction des images avec ffmpeg
echo Extraction des frames...
ffmpeg -hide_banner -loglevel error -i "%file%" pipboy_frame_%%04d.png
if errorlevel 1 (
    echo ERREUR lors de l'extraction des images.
    pause
    exit /b 1
)

:: Génération des fichiers .plymouth et .script
(
echo [Plymouth Theme]
echo Name=PipBoy
echo Description=Animation de demarrage convertie depuis GIF/Video
echo ModuleName=script
echo.
echo [script]
echo ImageDir=/usr/share/plymouth/themes/pipboy
echo ScriptFile=/usr/share/plymouth/themes/pipboy/pipboy.script
) > pipboy.plymouth

(
echo for (i = 1; i <= 9999; i++) {
echo ^    file = "pipboy_frame_" + sprintf("%%04d", i) + ".png";
echo ^    if (! FileExists(file)) break;
echo ^    img = Image(file);
echo ^    screen_w = Window.GetWidth();
echo ^    screen_h = Window.GetHeight();
echo ^    img_w = Image.GetWidth(img);
echo ^    img_h = Image.GetHeight(img);
echo ^    x = (screen_w - img_w) / 2;
echo ^    y = (screen_h - img_h) / 2;
echo ^    Window.Clear();
echo ^    Window.DrawImage(img, x, y);
echo ^    Plymouth.Sleep(0.04);
echo }
) > pipboy.script

echo.
echo Conversion terminee avec succes dans %CD%
echo Fichiers crees :
echo - pipboy.plymouth
echo - pipboy.script
echo - pipboy_frame_XXXX.png (sequence d'images)
echo.

pause
