# Loaded by script/console. Land helpers here.

Pry.config.prompt = lambda do |context, *|
  "[cubrid2] #{context}> "
end
