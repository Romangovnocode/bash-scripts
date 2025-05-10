#/bin/bash


startercheck=1

#########################  System  ############################
# ф-я нужна для безопасного запуска части скрипта autocheck.sh в одном экземпляре, чтобы избежать повторного выполнения, пока предыдущий процесс ещё работает
startscript() {
    flock -w0 /var/run/autocheck.lock -c "sed -n '/^######systemline######$/,\$p' ${workdir}/autocheck.sh | /bin/bash"
    [[ $? -ne 0 ]] && {
		echo -e "`date '+%Y-%m-%d %T'` (INF): Процесс был запущен ранее" >> ${maindir}/autocheck.log
    } || {
		echo -e "`date '+%Y-%m-%d %T'` (INF): Процесс завершен" >> ${maindir}/autocheck.log
    }
}
# Эта функция делает то же самое, что и startscript(), но с режимом отладки (-x)
startscript_debug() {
    flock -w0 /var/run/autocheck.lock -c "sed -n '/^######systemline######$/,\$p; ' ${workdir}/autocheck.sh | /bin/bash -x"
    [[ $? -ne 0 ]] && {
		echo -e "`date '+%Y-%m-%d %T'` (INF): Процесс был запущен ранее" >> ${maindir}/autocheck.log 
    } || {
		echo -e "`date '+%Y-%m-%d %T'` (INF): Процесс завершен" >> ${maindir}/autocheck.log
    }
}

logfile=./autocheck.log
maindir=/work/autocheck/system
workdir=/work/autocheck
cd $maindir
# что делает условие:
# Допустим, сегодня 2025-01-20, а лог изменялся 2025-01-19 тогда --- autocheck.log > переименовывается в autocheck.log.01
# Если autocheck.log.01 уже был > он станет autocheck.log.02 и т. д
# autocheck.log.10 удаляется
# Создается свежий autocheck.log для новых записей.

# find ищет файл $logfile и выводит его дату 
# Если дата изменения лога не совпадает с текущей датой > значит, лог устарел тогда (ротирует логи) архивирует старые и создать новые
 if [[ `find $logfile -printf '%TY-%Tm-%Td'` != `date +'%Y-%m-%d'` ]]; then
 # вот тут сама ротация логов, циклом перебирает от 10 до 1
    for ((i=10;i>0;i--)); do
		ii=`printf "%02d\n" $i`
		iinew=`printf "%02d\n" $(($i+1))`
# удаляет самый старый лог autocheck.log.10 (если существует) если i=10, то файл autocheck.log.10 просто удаляется (т. к. .11 не нужен)
		[[ $i -eq 10 ]] && { 
			[[ -f ${logfile}.$ii ]] && { 
				rm -f ${logfile}.$ii
				continue 
			}
		}
# переименование остальных логов, eсли файл с текущим номером ($ii) существует, он переименовывается в следующий ($iinew)
# eсли mv завершился с ошибкой ($? -ne 0), в лог добавляется запись.
		[[ -f ${logfile}.$ii ]] && { 
			mv ${logfile}.$ii ${logfile}.$iinew # Переименовывает "autocheck.log.01" > ".02" и т. д.
			[[ $? -ne 0 ]] && { echo "Ошибка смещения логов" >> "${logfile}"; } # Если ошибка > пишет в лог
		}
    done
    mv ${logfile} ${logfile}.01 # Перемещает текущий лог в "autocheck.log.01"
    touch ${logfile} # ну и cоздает новый пустой лог-файл
fi
# эта ф-я 1) Активирует startercheck в autocheck.sh (меняет 0 > 1)
# 2) Запускает startscript в фоне, делая его независимым от текущего терминала. disown – удаляет процесс из списка задач текущей сессии.
start() {
    sed -i '/^startercheck/s/0/1/g' ${workdir}/autocheck.sh
    startscript & disown
}

stop() {
    sed -i '/^startercheck/s/1/0/g' ${workdir}/autocheck.sh # меняет в скрипте 1 на 0
    kill `ps aux | grep "flock.*autocheck.s[h]" | awk '{print $2}'` # принудительно завершает процесс, использующий flock для блокировки autocheck.sh | flock – утилита для блокировки файлов.
    exit
}
# если startercheck = 0 тогда блокирует запуск скрипта, если = 1 тогда норм и запускает в фоновом режиме 
run() {
    [[ ${startercheck} -eq 0 ]] && {
		echo -e "`date '+%Y-%m-%d %T'` (INF): ЗАПУСК ЗАПРЕЩЕН" >> ${maindir}/autocheck.log 
		exit 1
    } || {
		startscript & disown
    }
}
# записывает лог и вызывает основной скрипт startscript_debug с отладочным выводом, блокирует дублирующие запуски через flock
debug() {
    echo -e "`date '+%Y-%m-%d %T'` (DEBUG): ЗАПУСК DEBUG ПРОГРАММЫ" >> ${maindir}/autocheck.log 
    startscript_debug
}
# кейс конструкция анализирует первый аргумент например "./autocheck.sh start или stop,run,debug
# start - включает startercheck=1 и запускает скрипт
# stop - выключает startercheck=0 и убивает процесс
# run - проверяет startercheck и запускает/блокирует скрипт
# debug - то же, что run, но с отладочным выводом
# Если аргумент не распознан (*) - выводит подсказку:
case "${1}" in 
    "start")
    start
;;
    "stop")
    stop
;;
    "run")
    run
;;
    "debug")
    debug
;;
    * )
    echo "Только start/stop/run"
;;
esac
exit

######systemline######
#########################Переменные############################

maindir=/work/autocheck/system
workdir=/work/autocheck
cd ${maindir}					#Рабоча директория
checkdir=${workdir}/object			#Каталог с файлами обновлений ТО
PIDF=./checklock.lock				#PID файл
logfile=./autocheck.log				#Файл логирования действий
etalon=/work/RocketScript/etalon/etalon		#Файлы эталона
tasker=./tasklist.csv
HISTSQL=./LIST_SQL.csv
HISTFILE=./LIST_FILE.csv
difflist=./difflist.csv
typeGlobal='md'
checkPack=( ";;rpm" "SQL;;" "ZOPE;;" "set/" "reports/" "tander/(fsit)" "tander-tsdserver/tsdserver-mm-kognitive-[0-9]" "tander-tsdserver/yggdrasil-" "tander-tsdserver/tsdserver-[0-9]" "config/yum-repo-config-[0-9]" "www-servers/nginx-i586-[0-9]" )

#Необходимость проверки эталонных файлов для ТО
etmd=0
etmk=0
etgm=0
etdd=0
ethd=0
skipmd=0
skipmk=0
skipgm=0
skipdd=0
skiphd=0
#########################  Функции  ###########################

#Логирование:
#Входящие данные записываются в файл лога
say()
{
    echo -e "`date '+%Y-%m-%d %T'` (INF): $1" >> ${maindir}/autocheck.log
}

# Сравнение версий:
# Выполенние зависит от того какая версия выше и существует ли такое скриптовое обновление на ТО
# первый параметр X.X.X_etalon;update_name_etalon вторым указывается версия сверяемого объекта, третьем параметром идет тип поставки
# V2.1 Перешли на bash
checkversion() {
    if [[ x"${1}" == x"${2}" ]]; then
		return 0
    else
		bestVER=`echo -e "${1/*;/}\n${2/*;/}" | sort -V | tail -n1`
		if [[ x${bestVER} == x${1/*;/} ]]; then
			difflist+=( "${2:-$1;NO}${2:+;IS}$3" )
		fi
    fi
}

#Выгружаем общий список установленных обновлений (история отправки на ТО)
update_autochek() {
    echo "select
    c(tau.id_tp_updates)||';'||
    c(tau.file_code)||';'||
    c(tau.file_vers)||';'||
    c(tu.upd_name)||';'||
    c(tau.upd_date)||';'||
    c(tu.path)||';'||
    case when tbr.buildtype = 'ММ' then 'md'
    when tbr.buildtype = 'МК' then 'mk'
    when tbr.buildtype = 'ГМ' then 'gm'
    when tbr.buildtype = 'ХД' then 'hd' end ||';'||
    c(tu.monopol)||case when on_zope = 1 then ';ZOPE;' else ';FILE;' end||tbr.is_first_conf from tp_autocheck_updates tau
    left join tp_updates tu on tu.id=tau.id_tp_updates
    left join tp_build_reestr tbr on tbr.id = tau.id_tp_build_reestr
    where tau.file_code is not null and tau.enabled = 1
    order by tau.upd_date
    ;" | /opt/firebird/bin/isql 10.5.4.57:/base/stp_gm.gdb -user SADMIN -pass skyline 2>&1 |\
sed '/Database/d;/CONCATENATION/d;/===/d;/^$/d;s/^[ \t]*//;s/[ \t]*$//;s/^/ /;s/\.0000//g;s/^ //;s/\r//g' > ${HISTFILE}

    echo "select
    tau.id_tp_updates ||';'||
    tau.sql_code||';'||
    tau.sql_vers||';'||
    tu.upd_name||';'||
    tau.upd_date||';'||
    tu.path||';'||
    case when tbr.buildtype = 'ММ' then 'md'
    when tbr.buildtype = 'МК' then 'mk'
    when tbr.buildtype = 'ГМ' then 'gm' 
    when tbr.buildtype = 'ХД' then 'hd' end ||';'||
    tu.monopol||';SQL;'|| tbr.is_first_conf from tp_autocheck_updates tau
    left join tp_updates tu on tu.id=tau.id_tp_updates
    left join tp_build_reestr tbr on tbr.id = tau.id_tp_build_reestr
    where tau.sql_code is not null and tau.enabled = 1
    order by tau.upd_date
    ;" | /opt/firebird/bin/isql 10.5.4.57:/base/stp_gm.gdb -user SADMIN -pass skyline 2>&1 | sed '/Database/d;/CONCATENATION/d;/===/d;/^$/d;s/^[ \t]*//;s/[ \t]*$//;s/^/ /;s/\.0000//g;s/^ //;s/\r//g' > ${HISTSQL}
    [[ -n `grep "Statement failed" ${HISTFILE} ${HISTSQL} ${statuscheck}` ]] && exit 5
    say "Выгрузка истории обновлений завершена"
}

# Получение данных о ТО ориентируясь на файл задания
# Выполяется в цикле
filer_file() {
    codeOO=`grep -oP '(?<=[^0-9])[0-9]{6}$' <<< ${checkfile}`
    if [[ -z ${codeOO} ]]; then
		say "${checkfile} - Не определен код ОО"
		continue
    fi
    if [[ -n `grep 'salepoint-hd' ${checkfile}` ]]; then
		typeOO=hd
    else
		typeOO=`sed -rn 's/.*WHS\.([GM][DMK]);.*/\L\1/p' ${checkfile}`
    fi
    if [[ -z ${typeOO} ]]; then
		say "${code} - Не определен тип ОО, похоже отсутствует WHS.[A-Z][A-Z]"
		continue
    fi
    if [[ -n `grep 'pprint-ds' ${checkfile}` ]]; then
        etall=etdd
        etalonAll=${workdir}/etalon/etalondd
        if [ ${!etall} -eq 0 ]; then
            if [[ $etdd -eq 0 ]]; then
                grep -iv 'pprint' ${etalon}${typeOO} | grep -P "`sed 's/ /|/g' <<< ${checkPack[@]}`" > ${etalonAll}
                if [[ $? -eq 0 ]];then
                    etdd=1
                else
                    skipdd=1
                fi
            fi
        fi
    else
        etall=et${typeOO}
        etalonAll=${workdir}/etalon/etalon${typeOO}
        if [ ${!etall} -eq 0 ]; then
            grep -P "`sed 's/ /|/g' <<< ${checkPack[@]}`" ${etalon}${typeOO} > ${etalonAll}
        fi
    fi

    if [[ ${typeOO} == gm ]]; then
		if [ `date +%H` -lt 11 ] || [ `date +%H` -gt 16 ]; then
			continue
		fi
    fi
    unset difflist
    [ ${!etall} -eq 0 ] && {
		if [[ ! -f ${etalonAll} ]] || [[ $(((`date +%s` - `find ${etalonAll} -printf '%Ts'`)/86400)) -ge 1 ]]; then
			say "${codeOO}: etalon${typeOO} не актуален или отсутствует, в текущей итерации сверки будут пропущены все объекты данного формата"
			eval skip${typeOO}=1
			eval et${typeOO}=1
			continue
		fi
		eval et${typeOO}=1
		eval etalon${typeOO}=`md5sum ${etalonAll} | awk '{print $1}'`
    }
    eval allMD5=etalon${typeOO}
    eval allSKIP=skip${typeOO}
    [[ ${!allSKIP} -eq 1 ]] && { say "$codeOO - etalon$typeOO не актуален либо отсутствует"; continue; }
    if [[ ${!allMD5} == `md5sum $checkfile | awk '{print $1}'` ]]; then
		say "${codeOO} - совпадает c эталоном по md5"
		mv -f ${checkfile} ${checkfile/checkfile/complite_autocheck}
		continue
    fi
}

# Проверка файлов с обновлениями
filecheckver () {
#    if [[ `grep -vc -f ${checkfile} ${etalonAll}` -eq 0 ]]; then
#        mv -f ${checkfile} ${checkfile/checkfile/complite_autocheck}
#        continue
#        return 0
#    fi
enterWhile=0
    while read etline; do
        enterWhile=1
		type_task="${etline/;;*/}"
		update_line="${etline/*;;/}"
		update_name="${update_line/;*/}"
		verinTO=`grep "^${type_task};;${update_name};" ${checkfile}`
		checkversion "${update_line}" "${verinTO/*;;/}" "${type_task}"
	#done < <(cat "${etalonAll}")
    done < <(grep -v -f ${checkfile} ${etalonAll})
    if [[ ${enterWhile} -eq 0 ]]; then
        mv -f ${checkfile} ${checkfile/checkfile/complite_autocheck}
        continue
        return 0
    fi
}

# Проверка и выбор обновлений
checker_update() {
    cp -f /dev/null "${tasker}"
    for ((i=0;i<${#difflist[@]};i++)); do
		difftask="${difflist[$i]}"
		diffupd="${difftask%;*}"
		diffver="${diffupd/*;/}"
		diffname="${diffupd/;*/}"
		difftype="${difftask/*;[IN][SO]/}"
		if [[ ${difftype} == "SQL" ]]; then
			hist_update=${HISTSQL}
		elif [[ ${difftype} == "FILE" ]] || [[ ${difftype} == "ZOPE" ]]; then
			hist_update=${HISTFILE}
		fi
		if [[ "${difftask##*;}" == "NO${difftype}" ]]; then
			beforecheck=`cat "${tasker}" | wc -l`
			grep ";${diffname};" "${hist_update}" | awk -F';' '{if ($10 == 1) print $0}' | sort  -t';' -k5 -u | grep ";${typeOO};"| sed "s/^/${codeOO};/g" >> "${tasker}" || continue
			aftercheck=`cat "${tasker}" | wc -l`
			if [[ ${aftercheck} -gt ${beforecheck} ]]; then
				grep ";${diffname};" "${hist_update}" | sort  -t';' -k5 | grep ";${typeOO};" | awk "_=_||/;${diffver};/" | grep -v ";${diffver};" | sed "s/^/$codeOO;/g" >> ${tasker} || continue
			fi
		elif [[ "${difftask##*;}" == "IS${difftype}" ]]; then
			grep ";${diffname};" "${hist_update}" | sort  -t';' -k5 | grep ";${typeOO};" | awk "_=_||/;${diffver};/" | grep -v ";${diffver};" | sed "s/^/$codeOO;/g" >> ${tasker} || continue
		fi
    done
    for exupd in `cat ${tasker} | awk -F';' '{print $2}' | sort | uniq -d`;do
        while [[ `grep -c "^$codeOO;$exupd;.*;SQL;[01]$" ${tasker}` -gt 1 ]]; do
            sed -i "/`grep "^$codeOO;$exupd;.*;SQL;[01]$" ${tasker} | head -n 1 | sed 's/\//\\\\\\//g'`/d" ${tasker}
        done
        while [[ `grep -Pc "^$codeOO;$exupd;.*;(FILE|ZOPE);[01]$" ${tasker}` -gt 1 ]]; do
            sed -i "/`grep -P "^$codeOO;$exupd;.*;(FILE|ZOPE);[01]$" ${tasker} | head -n 1 | sed 's/\//\\\\\\//g'`/d" ${tasker}
        done
        if [[ `grep -c "^$codeOO;$exupd;" ${tasker}` -ge 2 ]]; then
            sed -i -r "/^$codeOO;$exupd;/s/;SQL;/;SQL-FILE;/g;/^$codeOO;$exupd;.*;(FILE|ZOPE);[01]$/d;" ${tasker}
        fi
    done
}
#Отправитель обновления
task_send() {
    sendersh=/home/rebenok/manny.sh
    if [[ $typeOO == gm ]]; then
		sender() {
			if [[ $flagMON -eq 1 ]]; then
				say "monopol '1' '$task_name$sostav$task_path' 'autocheck' '20' '$codeOO'"
					${sendersh} ${typeOO^^} "1" "${task_name}${sostav}${task_path}" 'autocheck_new' "${codeOO}" '0' 'Терминал ИЛИ Бэкап'
			else
				say "'$task_name' '$sostav' '$task_path' 'autocheck' 'stpupdate' '0' '$codeOO'"
					${sendersh} ${typeOO^^} "${task_name}" ${sostav} "${task_path}" 'autocheck_new' 'stpupdate' '0' "${codeOO}" 'Терминал ИЛИ Бэкап' 'noparams' 'nofile'
			fi
		}
    elif [[ $typeOO == md ]] || [[ $typeOO == mk ]] || [[ $typeOO == hd ]]; then
		sender() {
			if [[ $flagMON -eq 1 ]]; then
				say "monopol '1' '$task_name$sostav$task_path' 'autocheck' '20' '$codeOO'"
					${sendersh}  "`sed 's/[kdh]/m/;s/[d]/m/;s/./\U&/g' <<< $typeOO`" "1" "${task_name}${sostav}${task_path}" 'autocheck_new' '20' "${filetask}" 'noparams' 'nofile'
			else
				say "'$task_name' '$sostav' '$task_path' 'autocheck' 'stpupdate' '0' '$codeOO'"
					${sendersh}  "`sed 's/[kdh]/m/;s/[d]/m/;s/./\U&/g' <<< $typeOO`" "${task_name}" ${sostav} "${task_path}" 'autocheck_new' 'stpupdate' '0' "${filetask}" 'noparams' 'nofile'
			fi
		}
    fi
	
	grep "^$codeOO" ${tasker} | sort -t';' -k6,6 | while read creat_task; do
	#Выбираем монопольное или не монопольное обновление и на основании формируем задание
		# А вот тут у нас где-то стакнулось наименование обновления при сборке, из-за чего мы его потом не смогли найти
		task_name=`echo "$creat_task" | awk -F';' '{print $5}'`
		task_path=`echo "$creat_task" | awk -F';' '{print $7}'`
		flagMON=`echo "$creat_task" | awk -F';' '{print $9}'`
		sostavTASK=`echo "$creat_task" | awk -F';' '{print $10}'`

		if [[ $flagMON -eq 0 ]] && [[ $sostavTASK == 'SQL' ]]; then
			sostav="0 1"
		elif [[ $flagMON -eq 0 ]] && [[ $sostavTASK =~ ^[FZ][IO][LP]E ]]; then
			sostav="1 0"
		elif [[ $flagMON -eq 0 ]] && [[ $sostavTASK == 'SQL-FILE' ]]; then
			sostav="1 1"
		elif [[ $flagMON -eq 1 ]] && [[ $sostavTASK == 'SQL' ]]; then
			sostav="-!-0-!-1-!-"
		elif [[ $flagMON -eq 1 ]] && [[ $sostavTASK =~ ^[FZ][IO][LP]E ]]; then
			sostav="-!-1-!-0-!-"
		elif [[ $flagMON -eq 1 ]] && [[ $sostavTASK == 'SQL-FILE' ]]; then
			sostav="-!-1-!-1-!-"
		else
			say "$task_name cостав не определен"
			continue
		fi
		sender
		#sleep 1
	done
	
	mv -f ${checkfile} ${checkfile/checkfile/complite_autocheck}
}

#########################  Скрипт  ###########################
for type in $typeGlobal; do
    counter_file=`ls ${checkdir}/${type}/checkfile_* 2>/dev/null |tail -n 1 | wc -l`
    if [ ${counter_file} -gt 0 ]; then
        say "Задания для сверки присутствуют"
        update_autochek
    else
        say "В директории 0 файлов заданий для сверки, выходим"
        exit 0
    fi
    guidaction=`date +'%Y-%m-%d' | md5sum | sed 's/ .*//g'`
    filetaskcode="/home/rebenok/list_mm/spudy_${guidaction}.txt"
    filetask="spudy_${guidaction}.txt"

	#######################Цикл заданий###########################
	#    for checkfile in ${checkdir}/$type/checkfile_${CodeTO}; do
	for checkfile in ${checkdir}/$type/checkfile_*; do
		filer_file
		filecheckver
		checker_update
		[[ ${#difflist[@]} -gt 0 ]] && {
			say "$typeOO -> $codeOO: diff${#difflist[@]} -> `echo ${difflist[@]}`"
			echo $codeOO > ${filetaskcode}
			task_send
		} || {
			mv -f ${checkfile} ${checkfile/checkfile/complite_autocheck}
		}
	done
done
