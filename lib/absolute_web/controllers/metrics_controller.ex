defmodule AbsoluteWeb.MetricsController do
  use AbsoluteWeb, :controller

  def scrape(conn, _params) do
    memory = :erlang.memory()
    proc_count = :erlang.system_info(:process_count)
    proc_limit = :erlang.system_info(:process_limit)
    schedulers = :erlang.system_info(:schedulers_online)
    run_queue = :erlang.statistics(:total_run_queue_lengths)

    metrics = """
    # HELP vm_memory_total_bytes Total allocated BEAM memory in bytes
    # TYPE vm_memory_total_bytes gauge
    vm_memory_total_bytes #{memory[:total]}

    # HELP vm_memory_processes_bytes BEAM memory allocated to process stacks and heaps
    # TYPE vm_memory_processes_bytes gauge
    vm_memory_processes_bytes #{memory[:processes]}

    # HELP vm_memory_atom_bytes BEAM memory allocated to atoms
    # TYPE vm_memory_atom_bytes gauge
    vm_memory_atom_bytes #{memory[:atom]}

    # HELP vm_memory_binary_bytes BEAM memory allocated to reference-counted binaries
    # TYPE vm_memory_binary_bytes gauge
    vm_memory_binary_bytes #{memory[:binary]}

    # HELP vm_processes_total Current active BEAM process count
    # TYPE vm_processes_total gauge
    vm_processes_total #{proc_count}

    # HELP vm_processes_limit Maximum allowed BEAM process limit
    # TYPE vm_processes_limit gauge
    vm_processes_limit #{proc_limit}

    # HELP vm_schedulers_online Number of active CPU schedulers
    # TYPE vm_schedulers_online gauge
    vm_schedulers_online #{schedulers}

    # HELP vm_run_queue_length Total BEAM run queue length
    # TYPE vm_run_queue_length gauge
    vm_run_queue_length #{run_queue}
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
  end
end
