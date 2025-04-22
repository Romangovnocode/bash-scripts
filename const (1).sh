#!/bin/sh
set -e # это завершает скрипт при ошибках, наверное придется убрать, но для перестраховки добавил 

# Переменные
maindir=/work/menshhikov/wr01809/
result=${maindir}/resultTO.txt			# конечный файлик
list_TO=${maindir}/listTO.txt            # тут коды нужных ТО
keyPath=/work/menshhikov/wr00937/key
theme='Голдман скрипт'
email=korobeynikov_nb@magnit.ru,ognev_oi@magnit.ru,poroykova_uv@magnit.ru
ccopy=lavrinenko_ra@magnit.ru  # Через неделю после тестов можно будет отключить

# На всякий случай делаем махинации с кодировкой
export NLS_LANG=RUSSIAN_RUSSIA.CL8MSWIN1251

# Логирование ___________
say() {
    echo "`date '+%Y-%m-%d %T'` - (${2:-INFO}) --> $1" >> $maindir/log.log
}
#________________________
# закомментил на всякий, а то просто ввод ключа ошибку выплюнуть
# $keyPath/svc_robotstp_pem_key  
# Функция для выполнения SQL-запроса
listenQ() {
    echo "select (SELECT code FROM rep_mdenterprise) as CODE, cosnt.NAME,
    case cosnt.VBOOL
    when 1 then 'ON'
    when 0 then 'OFF'
    end  as PRIZNAK,
    cosnt.lastdate
    From constant cosnt where NAME='Проверка_СГ_показать_УО';" | /opt/firebird/bin/isql -t '^' -user sadmin -pass $PSWD /base/$WHSBASE.gdb | sed -r '/^(Database|[= \t]*$|[ \t]*RES_CODE)/d;s/^[ \t]+//'
}

# Либы для скулы
export LD_LIBRARY_PATH=/usr/lib/oracle/11.2/client64/lib:$LD_LIBRARY_PATH
export ORACLE_HOME=/usr/lib/oracle/11.2/client
export TNS_ADMIN=/usr/lib/oracle/11.2/client64/lib
export NLS_LANG=RUSSIAN_RUSSIA.CL8MSWIN1251

# Очистка файла результатов
> "$result"

# Проверка существования файла listTO.txt
if [ ! -f "$list_TO" ]; then
    say "Файл $list_TO не найден" "ERROR"
    exit 1
fi

# Начало цикла по мониторингу
while read line ; do
    codeTO=$(awk -F';' '{print $1}' <<< "$line")

    # Проверка доступности сервера
    ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null svc_robotstp@omd_$codeTO.onlinemm.corp.tander.ru -i $keyPath/svc_robotstp_pem_key -p 2223 :

    if [ $? -ne 0 ]; then
        # Если не доступен, пропустить и выдать ошибку
        say "Не доступен по ssh $codeTO" "ERROR"
        echo "$codeTO; SSH недоступен" >> "$result"
        continue
    else
        say "Доступен по ssh $codeTO continue"
        # Записываем результат SQL-запроса "ON" или "OFF" в $request
        request=$(ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null svc_robotstp@omd_$codeTO.onlinemm.corp.tander.ru -i $keyPath/svc_robotstp_pem_key -p 2223 /bin/bash << EOF
sudo su root
. /base/ibsettings
listenQ
EOF
        )

        # Проверка на пустой результат
        if [ -z "$request" ]; then
            request="N/A"
        fi

        # Запись результата в общий файл
        echo "$codeTO; $request" >> "$result"
    fi
done < <(awk -F';' '!/^[ \t]*$/{print $1";"$2";"$3}' "$list_TO")

# Отправка email с результатами
echo -e "Добрый день.\nОтчет во вложении" | mailx -s "$theme" -a "$result" -c "$ccopy" "$email"