# Questa GUI setup for interactive Ibex UVM simulation.
#
# Makefile sets ibex_cov_db_arg before sourcing this script. The simulator
# remains paused at time 0 so signals can be added to Wave before Run-All.

if {![info exists ibex_cov_db_arg] || $ibex_cov_db_arg eq ""} {
  echo "ERROR: ibex_cov_db_arg is not defined"
  return -code error
}

set ibex_cov_db [file normalize $ibex_cov_db_arg]
file mkdir [file dirname $ibex_cov_db]

proc ibex_show_results {} {
  global ibex_cov_db

  echo "Ibex GUI: saving coverage to $ibex_cov_db"
  if {[catch {
    coverage save -codeAll -assert -cvg $ibex_cov_db
  } coverage_error]} {
    echo "WARNING: coverage save failed: $coverage_error"
  } elseif {[file exists $ibex_cov_db]} {
    echo "Ibex GUI: saved UCDB: $ibex_cov_db"
  } else {
    echo "WARNING: coverage save returned without creating $ibex_cov_db"
  }

  catch {view coverage}
  catch {view assertions}
}

# Preserve Questa's native run command once. This makes the script safe to
# source again without stacking wrappers or losing the original command.
if {[llength [info commands ibex_builtin_run]] == 0} {
  if {[catch {rename run ibex_builtin_run} hook_error]} {
    echo "ERROR: cannot install Run-All hook: $hook_error"
    return -code error
  }
}

proc run {args} {
  set command [linsert $args 0 ibex_builtin_run]
  set run_status [catch {uplevel 1 $command} run_result run_options]

  # UVM calls $finish after report_phase. In interactive Questa this makes
  # "run -all" return while keeping the GUI open, so coverage is complete.
  if {[lsearch -exact $args "-all"] >= 0} {
    ibex_show_results
  }

  if {$run_status != 0} {
    return -options $run_options $run_result
  }
  return $run_result
}

onfinish stop
catch {view objects}
catch {view wave}
echo "Ibex GUI ready: add signals to Wave, then press Run-All."
