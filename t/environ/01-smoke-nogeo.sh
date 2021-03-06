#!lib/test-in-container-environ.sh
set -ex

mc=$(environ mc $(pwd))
$mc/gen_env MIRRORCACHE_CITY_MMDB=""
$mc/start
$mc/status

ap8=$(environ ap8)
ap7=$(environ ap7)

for x in $mc $ap7 $ap8; do
    mkdir -p $x/dt/{folder1,folder2,folder3}
    echo $x/dt/{folder1,folder2,folder3}/{file1,file2}.dat | xargs -n 1 touch
done

$ap7/start
$ap7/curl /folder1/ | grep file1.dat

$ap8/start
$ap8/curl /folder1/ | grep file1.dat


$mc/db/sql "insert into server(hostname,urldir,enabled,country,region) select '127.0.0.1:1304','','t','us','na'"
$mc/db/sql "insert into server(hostname,urldir,enabled,country,region) select '127.0.0.1:1314','','t','de','eu'"

$mc/curl /download/folder1/file1.dat

$mc/backstage/job folder_sync_schedule_from_misses
$mc/backstage/job folder_sync_schedule
$mc/backstage/shoot

$mc/backstage/job -e mirror_scan -a '["/folder1"]'
$mc/backstage/shoot

$mc/db/sql "select * from minion_jobs order by id"

$mc/curl /download/folder1/ | grep file1.dat
$mc/curl -I /download/folder1/file1.dat | grep -C10 302 | grep -E "($($ap7/print_address)|$($ap8/print_address))"

###################################
# test files are removed properly
rm $mc/dt/folder1/file1.dat

# resync the folder
$mc/backstage/job folder_sync_schedule
$mc/backstage/job -e mirror_probe -a '["/folder1"]'
$mc/backstage/shoot

$mc/curl -s /download/folder1/ | grep file1.dat || :
if  $mc/curl -s /download/folder1/ | grep file1.dat ; then
    fail file1.dat was deleted
fi
