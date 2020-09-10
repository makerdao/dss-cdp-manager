#!/bin/bash
rm -rf coverage
mkdir -p coverage
dapp --use solc:0.5.16 build
# Generate code coverage
hevm dapp-test --coverage > coverage/coverage.log
cd coverage
# split coverage report into multiple files
csplit -k coverage.log '/\*\*\*\*\*/' {99}
# find our contracts (present in '/src' folder) and export output into final_result.log file
grep -l " src/" xx* | xargs cat >> final_result.log
rm xx*

# Process coverage result
totalLines=`wc -l final_result.log | awk '{print $1}'`
skipLines=`grep ';;;;;' final_result.log | wc -l`
emptyLines=`grep '\.\.\.\.\.' final_result.log | wc -l`

uncovLines=`grep '#####' final_result.log | wc -l`
coveredLines=`grep '^     ' final_result.log | wc -l`

actualCode=`expr $totalLines - $skipLines - $emptyLines`
coverage=`expr $coveredLines \* 100 / $actualCode`

echo "Total Lines: $totalLines"
echo "Skip Lines: $skipLines"
echo "Empty Lines: $emptyLines"
echo "Actual Code Lines: $actualCode"
echo "Covered Lines: $coveredLines"
echo "Uncovered Lines: $uncovLines"

echo "Code coverage: $coverage%"