#!/bin/bash

function generate_dependence_results {
  local benchSuite="$1" ;

  # Check if the benchmark suite has been compiled
  if ! test -d ${benchSuite}/benchmarks ; then
    return ;
  fi
  echo "Benchmark suite $i" ;

  # Create the output directory
  currentDepsResult="${ivResult}/${benchSuite}" ;
  mkdir -p $currentDepsResult ;

  # Collect the data
  pushd ./ &>/dev/null ;
  cd ${benchSuite}/benchmarks ;
  for j in `ls` ; do
    if ! test -d $j ; then
      continue ;
    fi
    if ! test -e ${j}/baseline_with_metadata.bc ; then
      continue ;
    fi
    echo "  Benchmark $j" ;

    pushd ./ &>/dev/null ;
    cd $j ;

    # NOELLE
    mkdir -p ${currentDepsResult}/noelle ;
    if ! test -e ${currentDepsResult}/noelle/${j}.txt ; then
      noelle-pdg-stats baseline_with_metadata.bc &> ${currentDepsResult}/noelle/${j}.txt
    fi

    # LLVM
    mkdir -p ${currentDepsResult}/llvm ;
    if ! test -e ${currentDepsResult}/llvm/${j}.txt ; then
      noelle-meta-pdg-clean baseline_with_metadata.bc baseline_with_metadata_llvm.bc ;
      noelle-meta-pdg-embed -noelle-disable-pdg-allocaa -noelle-disable-pdg-svf -noelle-disable-pdg-reaching-analysis -noelle-disable-loop-aware-dependence-analyses baseline_with_metadata_llvm.bc -o baseline_with_metadata_llvm.bc ;
      noelle-pdg-stats baseline_with_metadata_llvm.bc &> ${currentDepsResult}/llvm/${j}.txt ;
    fi

    popd &>/dev/null ;
  done
  popd &>/dev/null ;

  return ;
}

function analyze_results {
  local benchSuite="$1" ;
  currentDepsResult="${ivResult}/${benchSuite}" ;

  # Check if the benchmark suite has raw data
  if ! test -d ${currentDepsResult}/noelle ; then
    return ;
  fi

  # Analyze the data
  pushd ./ &>/dev/null ;
  cd ${currentDepsResult}/noelle ; 
  if ! test -e ../benchmarks.txt ; then
    touch ../benchmarks.txt ;
    for currentTemp in `ls` ; do
      if test -d $currentTemp ; then
        continue ;
      fi
      echo "$currentTemp" | sed 's/\.txt//g' >> ../benchmarks.txt
    done
  fi

  if ! test -e ../noelle.txt ; then
    ${origDir}/scripts/extract_dependences.sh > ../noelle.txt
  fi

  if ! test -e ../max.txt ; then
    ${origDir}/scripts/extract_max_dependences.sh > ../max.txt 
  fi

  cd ../llvm ;
  if ! test -e ../llvm.txt ; then
    ${origDir}/scripts/extract_dependences.sh > ../llvm.txt
  fi

  paste ../benchmarks.txt ../noelle.txt ../llvm.txt ../max.txt > ../absolute_values.txt ;
  awk '{
      printf("%s %f %f\n", $1, ($2 / $4) * 100, ($3 / $4) * 100);
    }' ../absolute_values.txt > ../relative_values.txt ;

  # Clean
  rm ../max.txt ../noelle.txt ../llvm.txt ../benchmarks.txt ;

  popd &>/dev/null ;
  return ;
}

# Define the directory where we are going to dump the results
origDir=`pwd` ;
ivResult="${origDir}/results/current_machine/dependences"; 

# Generate the results for all benchmarks in all benchmark suites
pushd ./ &>/dev/null ;
cd results/current_machine/IR ;
for i in `ls` ; do
  if ! test -d $i ; then
    continue ;
  fi

  # Generate the raw data
  generate_dependence_results $i ;

  # Analyze the raw data
  analyze_results $i ;

done
popd &>/dev/null ;
