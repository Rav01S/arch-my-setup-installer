#!/bin/bash
#
# Скрипт автоматизации установки и настройки ПО для Arch Linux / CachyOS.
#
# ВАЖНО: Запускать с правами root (sudo ./setup_arch_full_v4.sh)
#
################################################################################

# Выход при ошибке
set -e

# Переменная для определения пользователя, запустившего скрипт через sudo
USER_NAME="${SUDO_USER:-$(whoami)}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

# Проверка, что скрипт запущен через sudo
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите этот скрипт с правами root через sudo."
  exit 1
fi
if [ -z "$SUDO_USER" ]; then
    echo "ПРЕДУПРЕЖДЕНИЕ: Не удалось определить пользователя. Некоторые пользовательские настройки могут быть пропущены."
    USER_NAME="root"
fi


echo "=== 1. ОБНОВЛЕНИЕ ЗЕРКАЛ И УСТАНОВКА ДОПОЛНИТЕЛЬНЫХ СЕРВИСОВ ==="

# 1.1. Обновление зеркал CachyOS (требуется sudo)
echo "Запуск: sudo cachyos-rate-mirrors"
cachyos-rate-mirrors

# 1.2. Установка git (если не установлен), необходимого для клонирования
if ! command -v git &> /dev/null; then
    echo "Git не найден. Установка Git..."
    pacman -S --noconfirm git
fi

# 1.3. Установка и запуск сервиса из репозитория
echo "Клонирование и запуск zapret-discord-youtube-linux..."

# Клонирование репозитория во временный каталог
CLONE_DIR="/tmp/zapret-discord-youtube-linux"
if [ -d "$CLONE_DIR" ]; then
    echo "Директория $CLONE_DIR уже существует. Удаляем старую."
    rm -rf "$CLONE_DIR"
fi

git clone https://github.com/Sergeydigl3/zapret-discord-youtube-linux.git "$CLONE_DIR"
cd "$CLONE_DIR"
echo "Запуск установочного скрипта..."
bash service.sh

# Возвращаемся в исходный каталог
cd - > /dev/null

echo "-----------------------------------------------------"

# 1.4. Синхронизация и обновление системы
echo "Синхронизация и обновление пакетов: sudo pacman -Syu"
pacman -Syu --noconfirm

echo "====================================================="
echo "=== 2. УСТАНОВКА YAY (AUR HELPER) ==="

if ! command -v yay &> /dev/null; then
    echo "yay не найден. Установка..."

    # Установка зависимостей для сборки
    pacman -S --noconfirm --needed git base-devel

    # Клонирование репозитория yay во временную директорию
    # Владельцем становится обычный пользователь, чтобы makepkg работал
    git clone https://aur.archlinux.org/yay.git /tmp/yay-install
    chown -R "$USER_NAME":"$USER_NAME" /tmp/yay-install
    cd /tmp/yay-install

    # Сборка и установка от имени пользователя
    # makepkg не должен запускаться от root
    echo "Запуск makepkg от имени пользователя $USER_NAME..."
    sudo -u "$USER_NAME" makepkg -si --noconfirm

    # Очистка
    cd - > /dev/null
    rm -rf /tmp/yay-install
else
    echo "yay уже установлен. Пропускаем."
fi


echo "====================================================="
echo "=== 3. УСТАНОВКА ОСНОВНЫХ ПАКЕТОВ (pacman и yay) ==="

# 3.1. Установка пакетов через pacman (официальные репозитории)
echo "Установка Discord, Steam, WPS Office, CUPS, Node.js, pnpm, PHP, PHP-SQLite и Composer через pacman..."
# Установлены nodejs, pnpm (менеджер пакетов), php, php-sqlite и composer (для Laravel)
pacman -S --noconfirm discord steam wps-office cups nodejs pnpm php php-sqlite composer

# 3.2. Установка пакетов через yay (AUR) от имени пользователя
echo "Установка Hiddify и Visual Studio Code (code) через yay..."
sudo -u "$USER_NAME" yay -S --noconfirm hiddify visual-studio-code-bin

echo "-----------------------------------------------------"

# 3.3. Настройка Laravel (Laravel Installer)
if [ "$USER_NAME" != "root" ]; then
    echo "Установка глобального установщика Laravel через Composer (для пользователя $USER_NAME)..."
    # Запуск composer от имени обычного пользователя для корректной установки
    sudo -u "$USER_NAME" bash -c "composer global require laravel/installer"

    # Напоминание о необходимости добавить путь Composer global bin в PATH
    COMPOSER_BIN_PATH="$USER_HOME/.composer/vendor/bin"
    echo "Для запуска 'laravel' из командной строки, убедитесь, что путь $COMPOSER_BIN_PATH добавлен в \$PATH вашего пользователя."
else
    echo "ПРЕДУПРЕЖДЕНИЕ: Глобальный установщик Laravel пропущен, так как скрипт был запущен напрямую от 'root'."
fi

echo "-----------------------------------------------------"

# 3.4. Загрузка и настройка YouTube Music AppImage
echo "Настройка YouTube Music AppImage..."

if [ "$USER_NAME" != "root" ]; then
    TARGET_DIR="$USER_HOME/.local/share/applications"
    TARGET_PATH="$TARGET_DIR/YTMusic.AppImage"
    DOWNLOAD_URL="https://github.com/th-ch/youtube-music/releases/download/v2.2.1/youtube-music-2.2.1.AppImage" # Обновленная ссылка

    # Устанавливаем curl, если не установлен
    if ! command -v curl &> /dev/null; then
        echo "Установка curl для загрузки файла..."
        pacman -S --noconfirm curl
    fi

    echo "Создание целевой директории: $TARGET_DIR"
    # Создание директории от имени пользователя
    sudo -u "$USER_NAME" mkdir -p "$TARGET_DIR"

    echo "Загрузка файла с AppImage..."
    curl -L "$DOWNLOAD_URL" -o /tmp/YTMusic.AppImage

    echo "Копирование AppImage в $TARGET_PATH и установка прав..."
    # Копирование и смена владельца
    cp /tmp/YTMusic.AppImage "$TARGET_PATH"
    chown "$USER_NAME":"$USER_NAME" "$TARGET_PATH"

    # Установка прав +x от имени пользователя
    sudo -u "$USER_NAME" chmod +x "$TARGET_PATH"

    # Удаление временного файла
    rm /tmp/YTMusic.AppImage

    echo "YouTube Music AppImage установлен и готов к запуску."
else
    echo "ПРЕДУПРЕЖДЕНИЕ: Установка AppImage пропущена, так как скрипт был запущен напрямую от 'root'."
fi


echo "====================================================="
echo "=== 4. НАСТРОЙКА HIDDIFY LAUNCHER С ПРАВАМИ ROOT ==="

# 4.1. Создание скрипта-лаунчера для запуска через pkexec
LAUNCHER_PATH="/usr/local/bin/hiddify-launcher.sh"
echo "Создание скрипта: $LAUNCHER_PATH"

tee "$LAUNCHER_PATH" > /dev/null << EOF
#!/bin/bash
# Самый надежный скрипт для запуска GUI с правами root в Hyprland через pkexec.

# --- 1. Проверяем наличие исполняемого файла Hiddify ---
HIDDIFY_PATH=\$(which hiddify)

if [ -z "\$HIDDIFY_PATH" ]; then
    notify-send "Hiddify Error" "Исполняемый файл 'hiddify' не найден в \$PATH."
    exit 1
fi

# --- 2. Собираем ключевые переменные окружения ---
# Включаем критичные переменные Wayland, XDG и, главное, D-BUS!
ENV_VARS="WAYLAND_DISPLAY=\$WAYLAND_DISPLAY XDG_RUNTIME_DIR=\$XDG_RUNTIME_DIR DISPLAY=\$DISPLAY XDG_SESSION_TYPE=\$XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS=\$DBUS_SESSION_BUS_ADDRESS"

# --- 3. Запускаем Hiddify через pkexec с явной передачей ENV_VARS ---
# pkexec env [ПЕРЕМЕННЫЕ] [ПРИЛОЖЕНИЕ]
pkexec env \$ENV_VARS "\$HIDDIFY_PATH"
EOF

# Делаем скрипт исполняемым
chmod +x "$LAUNCHER_PATH"

# 4.2. Создание .desktop файла для меню приложений
if [ "$USER_NAME" != "root" ]; then
    DESKTOP_ENTRY_DIR="$USER_HOME/.local/share/applications"
    DESKTOP_ENTRY_PATH="$DESKTOP_ENTRY_DIR/hiddify-root.desktop"
    echo "Создание ярлыка: $DESKTOP_ENTRY_PATH"

    # Обеспечиваем, что директория существует и имеет права пользователя
    sudo -u "$USER_NAME" mkdir -p "$DESKTOP_ENTRY_DIR"

    # Используем tee от имени пользователя
    sudo -u "$USER_NAME" tee "$DESKTOP_ENTRY_PATH" > /dev/null << EOF
[Desktop Entry]
Name=Hiddify (Root)
Comment=Hiddify Client launched with root privileges
Exec=$LAUNCHER_PATH
Terminal=false
Type=Application
Icon=hiddify
Categories=Network;Utility;VPN;
Keywords=vpn;proxy;hiddify;root;
EOF

    # Обновление базы данных .desktop файлов
    update-desktop-database "$DESKTOP_ENTRY_DIR"
fi


echo "====================================================="
echo "=== 5. УСТАНОВКА ILLOGICAL IMPULSE (ОПЦИОНАЛЬНО) ==="

read -p "Хотите установить Illogical Impulse? (y/n): " choice
case "$choice" in
  y|Y )
    echo "Установка Illogical Impulse..."
    # Установка curl, если он еще не установлен
    if ! command -v curl &> /dev/null; then
        pacman -S --noconfirm curl
    fi
    # Скачивание и запуск установщика
    II_SETUP_SCRIPT="/tmp/ii_setup.sh"
    curl -sL "https://ii.clsty.link/setup" -o "$II_SETUP_SCRIPT"
    chmod +x "$II_SETUP_SCRIPT"
    "$II_SETUP_SCRIPT"

    # Очистка
    rm "$II_SETUP_SCRIPT"
    echo "Illogical Impulse установлен."
    echo "Запуск приложения..."
    # Запуск от имени пользователя в фоновом режиме
    if [ "$USER_NAME" != "root" ]; then
        sudo -u "$USER_NAME" illogical-impulse &
    else
        illogical-impulse &
    fi
    ;;
  n|N )
    echo "Установка Illogical Impulse пропущена."
    ;;
  * )
    echo "Неверный ввод. Установка Illogical Impulse пропущена."
    ;;
esac


echo "====================================================="
echo "=== 6. ЗАВЕРШЕНИЕ ==="
echo "✅ Установка и настройка завершены."
echo "✅ Для использования Hiddify от имени root ищите 'Hiddify (Root)' в меню приложений."
echo "✅ Для использования CUPS необходимо включить и запустить сервис: sudo systemctl enable --now cups.service"
echo "✅ Для легкого запуска Laravel используйте: laravel new project_name && cd project_name && php artisan serve"
echo "====================================================="
