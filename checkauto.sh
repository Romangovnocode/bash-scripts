#/bin/bash


startercheck=1

#########################  System  ############################
# �-� ����� ��� ����������� ������� ����� ������� autocheck.sh � ����� ����������, ����� �������� ���������� ����������, ���� ���������� ������� ��� ��������
startscript() {
    flock -w0 /var/run/autocheck.lock -c "sed -n '/^######systemline######$/,\$p' ${workdir}/autocheck.sh | /bin/bash"
    [[ $? -ne 0 ]] && {
		echo -e "`date '+%Y-%m-%d %T'` (INF): ������� ��� ������� �����" >> ${maindir}/autocheck.log
    } || {
		echo -e "`date '+%Y-%m-%d %T'` (INF): ������� ��������" >> ${maindir}/autocheck.log
    }
}
# ��� ������� ������ �� �� �����, ��� � startscript(), �� � ������� ������� (-x)
startscript_debug() {
    flock -w0 /var/run/autocheck.lock -c "sed -n '/^######systemline######$/,\$p; ' ${workdir}/autocheck.sh | /bin/bash -x"
    [[ $? -ne 0 ]] && {
		echo -e "`date '+%Y-%m-%d %T'` (INF): ������� ��� ������� �����" >> ${maindir}/autocheck.log 
    } || {
		echo -e "`date '+%Y-%m-%d %T'` (INF): ������� ��������" >> ${maindir}/autocheck.log
    }
}

logfile=./autocheck.log
maindir=/work/autocheck/system
workdir=/work/autocheck
cd $maindir
# ��� ������ �������:
# ��������, ������� 2025-01-20, � ��� ��������� 2025-01-19 ����� --- autocheck.log > ����������������� � autocheck.log.01
# ���� autocheck.log.01 ��� ��� > �� ������ autocheck.log.02 � �. �
# autocheck.log.10 ���������
# ��������� ������ autocheck.log ��� ����� �������.

# find ���� ���� $logfile � ������� ��� ���� 
# ���� ���� ��������� ���� �� ��������� � ������� ����� > ������, ��� ������� ����� (�������� ����) ���������� ������ � ������� �����
 if [[ `find $logfile -printf '%TY-%Tm-%Td'` != `date +'%Y-%m-%d'` ]]; then
 # ��� ��� ���� ������� �����, ������ ���������� �� 10 �� 1
    for ((i=10;i>0;i--)); do
		ii=`printf "%02d\n" $i`
		iinew=`printf "%02d\n" $(($i+1))`
# ������� ����� ������ ��� autocheck.log.10 (���� ����������) ���� i=10, �� ���� autocheck.log.10 ������ ��������� (�. �. .11 �� �����)
		[[ $i -eq 10 ]] && { 
			[[ -f ${logfile}.$ii ]] && { 
				rm -f ${logfile}.$ii
				continue 
			}
		}
# �������������� ��������� �����, e��� ���� � ������� ������� ($ii) ����������, �� ����������������� � ��������� ($iinew)
# e��� mv ���������� � ������� ($? -ne 0), � ��� ����������� ������.
		[[ -f ${logfile}.$ii ]] && { 
			mv ${logfile}.$ii ${logfile}.$iinew # ��������������� "autocheck.log.01" > ".02" � �. �.
			[[ $? -ne 0 ]] && { echo "������ �������� �����" >> "${logfile}"; } # ���� ������ > ����� � ���
		}
    done
    mv ${logfile} ${logfile}.01 # ���������� ������� ��� � "autocheck.log.01"
    touch ${logfile} # �� � c������ ����� ������ ���-����
fi
# ��� �-� 1) ���������� startercheck � autocheck.sh (������ 0 > 1)
# 2) ��������� startscript � ����, ����� ��� ����������� �� �������� ���������. disown � ������� ������� �� ������ ����� ������� ������.
start() {
    sed -i '/^startercheck/s/0/1/g' ${workdir}/autocheck.sh
    startscript & disown
}

stop() {
    sed -i '/^startercheck/s/1/0/g' ${workdir}/autocheck.sh # ������ � ������� 1 �� 0
    kill `ps aux | grep "flock.*autocheck.s[h]" | awk '{print $2}'` # ������������� ��������� �������, ������������ flock ��� ���������� autocheck.sh | flock � ������� ��� ���������� ������.
    exit
}
# ���� startercheck = 0 ����� ��������� ������ �������, ���� = 1 ����� ���� � ��������� � ������� ������ 
run() {
    [[ ${startercheck} -eq 0 ]] && {
		echo -e "`date '+%Y-%m-%d %T'` (INF): ������ ��������" >> ${maindir}/autocheck.log 
		exit 1
    } || {
		startscript & disown
    }
}
# ���������� ��� � �������� �������� ������ startscript_debug � ���������� �������, ��������� ����������� ������� ����� flock
debug() {
    echo -e "`date '+%Y-%m-%d %T'` (DEBUG): ������ DEBUG ���������" >> ${maindir}/autocheck.log 
    startscript_debug
}
# ���� ����������� ����������� ������ �������� �������� "./autocheck.sh start ��� stop,run,debug
# start - �������� startercheck=1 � ��������� ������
# stop - ��������� startercheck=0 � ������� �������
# run - ��������� startercheck � ���������/��������� ������
# debug - �� ��, ��� run, �� � ���������� �������
# ���� �������� �� ��������� (*) - ������� ���������:
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
    echo "������ start/stop/run"
;;
esac
exit

######systemline######
#########################����������############################

maindir=/work/autocheck/system
workdir=/work/autocheck
cd ${maindir}					#������ ����������
checkdir=${workdir}/object			#������� � ������� ���������� ��
PIDF=./checklock.lock				#PID ����
logfile=./autocheck.log				#���� ����������� ��������
etalon=/work/RocketScript/etalon/etalon		#����� �������
tasker=./tasklist.csv
HISTSQL=./LIST_SQL.csv
HISTFILE=./LIST_FILE.csv
difflist=./difflist.csv
typeGlobal='md'
checkPack=( ";;rpm" "SQL;;" "ZOPE;;" "set/" "reports/" "tander/(fsit)" "tander-tsdserver/tsdserver-mm-kognitive-[0-9]" "tander-tsdserver/yggdrasil-" "tander-tsdserver/tsdserver-[0-9]" "config/yum-repo-config-[0-9]" "www-servers/nginx-i586-[0-9]" )

#������������� �������� ��������� ������ ��� ��
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
#########################  �������  ###########################

#�����������:
#�������� ������ ������������ � ���� ����
say()
{
    echo -e "`date '+%Y-%m-%d %T'` (INF): $1" >> ${maindir}/autocheck.log
}

# ��������� ������:
# ���������� ������� �� ���� ����� ������ ���� � ���������� �� ����� ���������� ���������� �� ��
# ������ �������� X.X.X_etalon;update_name_etalon ������ ����������� ������ ���������� �������, ������� ���������� ���� ��� ��������
# V2.1 ������� �� bash
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

#��������� ����� ������ ������������� ���������� (������� �������� �� ��)
update_autochek() {
    echo "select
    c(tau.id_tp_updates)||';'||
    c(tau.file_code)||';'||
    c(tau.file_vers)||';'||
    c(tu.upd_name)||';'||
    c(tau.upd_date)||';'||
    c(tu.path)||';'||
    case when tbr.buildtype = '��' then 'md'
    when tbr.buildtype = '��' then 'mk'
    when tbr.buildtype = '��' then 'gm'
    when tbr.buildtype = '��' then 'hd' end ||';'||
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
    case when tbr.buildtype = '��' then 'md'
    when tbr.buildtype = '��' then 'mk'
    when tbr.buildtype = '��' then 'gm' 
    when tbr.buildtype = '��' then 'hd' end ||';'||
    tu.monopol||';SQL;'|| tbr.is_first_conf from tp_autocheck_updates tau
    left join tp_updates tu on tu.id=tau.id_tp_updates
    left join tp_build_reestr tbr on tbr.id = tau.id_tp_build_reestr
    where tau.sql_code is not null and tau.enabled = 1
    order by tau.upd_date
    ;" | /opt/firebird/bin/isql 10.5.4.57:/base/stp_gm.gdb -user SADMIN -pass skyline 2>&1 | sed '/Database/d;/CONCATENATION/d;/===/d;/^$/d;s/^[ \t]*//;s/[ \t]*$//;s/^/ /;s/\.0000//g;s/^ //;s/\r//g' > ${HISTSQL}
    [[ -n `grep "Statement failed" ${HISTFILE} ${HISTSQL} ${statuscheck}` ]] && exit 5
    say "�������� ������� ���������� ���������"
}

# ��������� ������ � �� ������������ �� ���� �������
# ���������� � �����
filer_file() {
    codeOO=`grep -oP '(?<=[^0-9])[0-9]{6}$' <<< ${checkfile}`
    if [[ -z ${codeOO} ]]; then
		say "${checkfile} - �� ��������� ��� ��"
		continue
    fi
    if [[ -n `grep 'salepoint-hd' ${checkfile}` ]]; then
		typeOO=hd
    else
		typeOO=`sed -rn 's/.*WHS\.([GM][DMK]);.*/\L\1/p' ${checkfile}`
    fi
    if [[ -z ${typeOO} ]]; then
		say "${code} - �� ��������� ��� ��, ������ ����������� WHS.[A-Z][A-Z]"
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
			say "${codeOO}: etalon${typeOO} �� �������� ��� �����������, � ������� �������� ������ ����� ��������� ��� ������� ������� �������"
			eval skip${typeOO}=1
			eval et${typeOO}=1
			continue
		fi
		eval et${typeOO}=1
		eval etalon${typeOO}=`md5sum ${etalonAll} | awk '{print $1}'`
    }
    eval allMD5=etalon${typeOO}
    eval allSKIP=skip${typeOO}
    [[ ${!allSKIP} -eq 1 ]] && { say "$codeOO - etalon$typeOO �� �������� ���� �����������"; continue; }
    if [[ ${!allMD5} == `md5sum $checkfile | awk '{print $1}'` ]]; then
		say "${codeOO} - ��������� c �������� �� md5"
		mv -f ${checkfile} ${checkfile/checkfile/complite_autocheck}
		continue
    fi
}

# �������� ������ � ������������
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

# �������� � ����� ����������
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
#����������� ����������
task_send() {
    sendersh=/home/rebenok/manny.sh
    if [[ $typeOO == gm ]]; then
		sender() {
			if [[ $flagMON -eq 1 ]]; then
				say "monopol '1' '$task_name$sostav$task_path' 'autocheck' '20' '$codeOO'"
					${sendersh} ${typeOO^^} "1" "${task_name}${sostav}${task_path}" 'autocheck_new' "${codeOO}" '0' '�������� ��� �����'
			else
				say "'$task_name' '$sostav' '$task_path' 'autocheck' 'stpupdate' '0' '$codeOO'"
					${sendersh} ${typeOO^^} "${task_name}" ${sostav} "${task_path}" 'autocheck_new' 'stpupdate' '0' "${codeOO}" '�������� ��� �����' 'noparams' 'nofile'
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
	#�������� ����������� ��� �� ����������� ���������� � �� ��������� ��������� �������
		# � ��� ��� � ��� ���-�� ���������� ������������ ���������� ��� ������, ��-�� ���� �� ��� ����� �� ������ �����
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
			say "$task_name c����� �� ���������"
			continue
		fi
		sender
		#sleep 1
	done
	
	mv -f ${checkfile} ${checkfile/checkfile/complite_autocheck}
}

#########################  ������  ###########################
for type in $typeGlobal; do
    counter_file=`ls ${checkdir}/${type}/checkfile_* 2>/dev/null |tail -n 1 | wc -l`
    if [ ${counter_file} -gt 0 ]; then
        say "������� ��� ������ ������������"
        update_autochek
    else
        say "� ���������� 0 ������ ������� ��� ������, �������"
        exit 0
    fi
    guidaction=`date +'%Y-%m-%d' | md5sum | sed 's/ .*//g'`
    filetaskcode="/home/rebenok/list_mm/spudy_${guidaction}.txt"
    filetask="spudy_${guidaction}.txt"

	#######################���� �������###########################
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
