require "kinetic_sdk"

conn_task = KineticSdk::Task.new({
  app_server_url: "https://playground-brian-peterson.kinopsdev.io/app/components/task",
  username: "",
  password: "",
  options: {
    log_level: LOG_LEVEL,
  },
})

conn