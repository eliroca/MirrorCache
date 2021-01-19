#!lib/test-in-container-environs.sh
set -ex

# environ by number:
# 9  headquarter 
# 6 -NA subsidiary 
# 7 - EU subsidiary 
# 8- ASIA subsidiary 

for i in 6 7 8 9; do
    ./environ.sh pg$i-system2
    ./environ.sh mc$i $(pwd)/MirrorCache
    pg$i*/start.sh
    pg$i*/create.sh db mc_test
    pg$i*/sql.sh -f $(pwd)/MirrorCache/sql/schema.sql mc_test
    mc$i*/configure_db.sh pg$i
    mkdir -p mc$i/dt/{folder1,folder2,folder3}
    echo mc$i/dt/{folder1,folder2,folder3}/{file1,file2}.dat | xargs -n 1 touch
done

hq_address=$(mc9*/print_address.sh)
na_address=$(mc6*/print_address.sh)
eu_address=$(mc7*/print_address.sh)
as_address=$(mc8*/print_address.sh)

pg9*/sql.sh -c "insert into subsidiary(hostname,region) select '$na_address','na'" mc_test
pg9*/sql.sh -c "insert into subsidiary(hostname,region) select '$eu_address','eu'" mc_test
pg9*/sql.sh -c "insert into subsidiary(hostname,region) select '$as_address','as'" mc_test

mc9*/start.sh
MIRRORCACHE_REGION=na MIRRORCACHE_HEADQUARTER=$hq_address mc6*/start.sh
MIRRORCACHE_REGION=eu MIRRORCACHE_HEADQUARTER=$hq_address mc7*/start.sh
MIRRORCACHE_REGION=as MIRRORCACHE_HEADQUARTER=$hq_address mc8*/start.sh

curl --interface 127.0.0.2 -Is http://$hq_address/download/folder1/file1.dat | grep $na_address
curl --interface 127.0.0.3 -Is http://$hq_address/download/folder1/file1.dat | grep $eu_address
curl --interface 127.0.0.4 -Is http://$hq_address/download/folder1/file1.dat | grep $as_address

curl --interface 127.0.0.2 -Is http://$na_address/download/folder1/file1.dat | grep 200
curl --interface 127.0.0.3 -Is http://$na_address/download/folder1/file1.dat | grep $hq_address
curl --interface 127.0.0.4 -Is http://$na_address/download/folder1/file1.dat | grep $hq_address

curl --interface 127.0.0.2 -Is http://$eu_address/download/folder1/file1.dat | grep $hq_address
curl --interface 127.0.0.3 -Is http://$eu_address/download/folder1/file1.dat | grep 200
curl --interface 127.0.0.4 -Is http://$eu_address/download/folder1/file1.dat | grep $hq_address

curl --interface 127.0.0.2 -Is http://$as_address/download/folder1/file1.dat | grep $hq_address
curl --interface 127.0.0.3 -Is http://$as_address/download/folder1/file1.dat | grep $hq_address
curl --interface 127.0.0.4 -Is http://$as_address/download/folder1/file1.dat | grep 200