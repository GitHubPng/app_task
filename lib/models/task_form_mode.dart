/// Modo de edição do formulário de tarefa.
enum TaskFormMode {
  /// Criação ou edição avulsa / conversão de tipo.
  standard,

  /// Override pontual em uma data.
  occurrence,

  /// Nova versão da regra recorrente a partir de uma data.
  rule,
}
