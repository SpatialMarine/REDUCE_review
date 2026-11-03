# Reviewer 3: revisiones adicionales explícitas

El cambio permite aplicar una revisión adicional aunque el artículo tenga un único revisor válido o dos revisores que coincidan. **Un único revisor no se considera incompleto.** La nueva columna manual `apply_reviewer3` se distingue del indicador calculado `requires_adjudication`.

## Cómo usarlo con las 150 propuestas

1. Conserva una copia de seguridad del Excel revisado. La entrada debe contener la hoja `final_screening` y los campos manuales habituales.
2. Añade una columna llamada exactamente `apply_reviewer3` y escribe `TRUE` para los 150 IDs de las dos listas de propuestas (86 + 64). Usa `FALSE` o vacío en los demás. No actives todas las filas con feedback: también contienen decisiones históricas que quizá no deban reaplicarse.
3. En la configuración del script, `reviewer3_file` debe apuntar a ese archivo manual. Por defecto lee `output_data/abstract_screening/abstract_screening_reviewer3.xlsx`. El archivo exhaustivo entregado no se selecciona automáticamente por su nombre; se debe configurar la ruta o adoptar expresamente su contenido como entrada manual.
4. Ejecuta el script. Escribe resultados separados en `abstract_screening_reviewer3_updated.xlsx`, `abstract_screening_summary.xlsx` y `abstract_screening_final.xlsx`. No uses uno de esos tres nombres como entrada: la nueva protección detiene esa configuración para evitar sobrescribirla.
5. Comprueba las decisiones y la hoja `adjudication_pending`. Para reutilizar el libro actualizado, guarda primero una copia manual con otro nombre y configura esa copia como entrada. No basta con editar un archivo que el script no lee.

Un libro antiguo sin la nueva columna sigue funcionando: todas sus activaciones adicionales se consideran FALSE. El script no activa automáticamente propuestas por el color rojo, por su autor ni por contener alguna nota. Las adjudicaciones automáticas por discrepancia o decisión incompleta continúan funcionando incluso con `apply_reviewer3 = FALSE`; este control no las desactiva.

## Qué ocurre con cada campo

| Situación | Resultado |
|---|---|
| Revisión adicional TRUE con decisión de Reviewer 3 | Su Accepted/Rejected se usa como decisión final. |
| Revisión adicional TRUE sin decisión | Pending decision, con `decision_reviewer_3` en pending_fields. |
| FALSE/vacío sin discrepancia | Las respuestas anteriores de Reviewer 3 se conservan como historial; no anulan la decisión inicial. |
| Valor distinto de TRUE/FALSE/vacío | Error con los IDs afectados; no se transforma silenciosamente a FALSE. Se acepta true/false en minúsculas. |
| Variable aportada por Reviewer 3 en una adjudicación activa | Tiene prioridad sobre la clasificación inicial. |
| Variable vacía en Reviewer 3 y sin discrepancia | Se recupera el valor disponible de los revisores iniciales. Vacío no significa borrar expresamente un valor inicial. |
| Discrepancia aplicable sin resolver | Pending variables. Para Accepted solo obligan las variables discrepantes Topic/TaxaGroup/fishingGear; para Rejected, TA_exclCriteria discrepante. |
| Resultado Rejected | Las categorías finales Topic/TaxaGroup/fishingGear quedan vacías; las evaluaciones iniciales y el historial siguen disponibles. |
| Resultado Accepted | TA_exclCriteria_final queda vacío; los criterios iniciales permanecen en sus columnas originales. |
| Artículo ausente del subconjunto | Se conserva en el historial, incluido el control; no se añade al resultado actual. |

La lógica de precedencia y campos pendientes existente se reutiliza: no se impone que todos los Accepted tengan todas las categorías. `Resolved` significa que no quedan decisiones o discrepancias aplicables pendientes; **no certifica la elegibilidad científica definitiva**. Un Accepted puede ser una retención prudente para comprobar el texto completo.

Las salidas se escriben con writexl: no conservan necesariamente colores o formato manual del Excel de entrada. El archivo manual original permanece intacto y es la referencia para el texto rojo. Además, se mantiene el comportamiento previo por el que Accepted puede avanzar aunque tenga clasificación pendiente; comprueba la hoja de pendientes.

## Explicación de cada línea modificada del script

Los números corresponden a `src/05_summariseAbstractScreening.R` en este PR. Cada línea añadida o sustituida está documentada a continuación; también se explican comentarios y cierres de bloques. Las líneas eliminadas se sustituyen por estas operaciones: el select incluye ahora el control, el filtro distingue activación y feedback, la unión manual se adelanta y las condiciones de requerimiento/pendiente incluyen la activación explícita.

| Línea | Código | Explicación |
|---:|---|---|
| 50 | `# A manual input must never share a path with a generated output.` | Comentario: A manual input must never share a path with a generated output. |
| 51 | `generated_screening_files <- file.path(output_dir, c(` | Construye las rutas de los archivos que el script genera automáticamente. |
| 52 | `"abstract_screening_reviewer3_updated.xlsx",` | Incluye el libro actualizado entre las salidas que nunca pueden usarse directamente como entrada manual. |
| 53 | `"abstract_screening_summary.xlsx", "abstract_screening_final.xlsx"` | Incluye el resumen y el dataset final en la misma protección contra sobrescritura. |
| 54 | `))` | Cierra el bloque o la llamada y, cuando aparece %>%, continúa la transformación. |
| 55 | `if (tolower(normalizePath(reviewer3_file, winslash = "/", mustWork = FALSE)) %in%` | Normaliza la ruta de entrada y la pasa a minúsculas para comparar rutas en Windows; permite que el archivo aún no exista. |
| 56 | `tolower(normalizePath(generated_screening_files, winslash = "/", mustWork = FALSE))) {` | Compara la entrada con todas las rutas de salida; entra en el bloque si alguna coincide. |
| 57 | `stop("reviewer3_file must be separate from generated screening output files.")` | Detiene la ejecución antes de escribir si la entrada podría ser sobrescrita por una salida. |
| 58 | `}` | Cierra el bloque o la llamada y, cuando aparece %>%, continúa la transformación. |
| 67 | `# Optional manual opt-in for an additional review, including single-reviewer` | Comentario: Optional manual opt-in for an additional review, including single-reviewer |
| 68 | `# papers. Existing workbooks without this column keep their previous behaviour.` | Comentario: papers. Existing workbooks without this column keep their previous behaviour. |
| 69 | `reviewer3_control_column <- "apply_reviewer3"` | Define el nombre de la nueva columna opcional que introduce la activación manual explícita. |
| 160 | `if (!reviewer3_control_column %in% names(adjudication_decisions)) {` | Detecta libros antiguos que todavía no contienen la nueva columna. |
| 161 | `adjudication_decisions[[reviewer3_control_column]] <-` | Añade la columna únicamente a los datos cargados en memoria; no modifica el Excel original. |
| 162 | `rep("FALSE", nrow(adjudication_decisions))` | Asigna FALSE a cada fila antigua; rep también funciona si hay cero filas. |
| 163 | `}` | Cierra el bloque o la llamada y, cuando aparece %>%, continúa la transformación. |
| 166 | `select(all_of(c(adjudication_columns, reviewer3_control_column))) %>%` | Conserva las columnas manuales habituales y también la nueva columna; requires_adjudication sigue siendo un resultado calculado. |
| 168 | `mutate(apply_reviewer3 = str_to_upper(apply_reviewer3))` | Después de limpiar espacios y vacíos, convierte true/false a mayúsculas para aceptar diferencias de capitalización. |
| 170 | `invalid_review_controls <- adjudication_decisions %>%` | Inicia una tabla de filas cuyo control manual no es válido. |
| 171 | `filter(!is.na(apply_reviewer3), !apply_reviewer3 %in% c("TRUE", "FALSE"))` | Selecciona valores no vacíos distintos de TRUE/FALSE; evita interpretar silenciosamente un error como FALSE. |
| 172 | `if (nrow(invalid_review_controls) > 0) {` | Comprueba si se encontró al menos un control no válido. |
| 173 | `stop("apply_reviewer3 must contain TRUE, FALSE or blank. Invalid Paper ID(s): ",` | Detiene el proceso con un mensaje que indica los valores aceptados. |
| 174 | `paste(invalid_review_controls$paperID, collapse = ", "))` | Incluye los IDs afectados en el error para que se puedan localizar. |
| 175 | `}` | Cierra el bloque o la llamada y, cuando aparece %>%, continúa la transformación. |
| 177 | `adjudication_decisions <- adjudication_decisions %>%` | Continúa la preparación de las adjudicaciones cargadas después de validar el control manual. |
| 178 | `mutate(apply_reviewer3 = coalesce(apply_reviewer3 == "TRUE", FALSE)) %>%` | Convierte el texto a lógico: TRUE activa; FALSE y los vacíos se convierten en FALSE. |
| 180 | `apply_reviewer3 \| if_any(all_of(setdiff(adjudication_columns, "paperID")),` | Retiene una fila si está activada o si tiene algún dato manual de Reviewer 3; conserva activaciones cuya decisión aún está pendiente. |
| 181 | `~ !is.na(.x))` | Comprueba únicamente los campos manuales de Reviewer 3; excluye ID y control para no tratar cada FALSE como feedback. |
| 202 | `fishingGear_reviewer_3 = character(),` | Mantiene el campo de arte vacío y añade la coma necesaria para incorporar el nuevo control al esquema vacío. |
| 203 | `apply_reviewer3 = logical()` | Define el control como lógico en una tabla vacía; mantiene tipos compatibles cuando todavía no existe el archivo manual. |
| 505 | `# A manual opt-in is separate from the presence of an initial disagreement.` | Comentario: A manual opt-in is separate from the presence of an initial disagreement. |
| 506 | `additional_review_ids <- adjudication_decisions %>%` | Inicia la lista de artículos cuya revisión adicional se ha activado explícitamente. |
| 507 | `filter(apply_reviewer3) %>%` | Selecciona únicamente las activaciones TRUE. |
| 508 | `pull(paperID)` | Extrae sus IDs como vector; la asociación siempre se realiza por ID y no por posición. |
| 509 | `required_adjudication_ids <- union(` | Amplía el conjunto de adjudicaciones requeridas sin duplicar IDs. |
| 510 | `required_adjudication_ids,` | Conserva todos los requerimientos que ya existían por discrepancia o decisión incompleta. |
| 511 | `intersect(additional_review_ids, paper_summary$paperID)` | Añade solo las activaciones de artículos presentes en el subconjunto actual; los ausentes permanecen en el historial. |
| 512 | `)` | Cierra el bloque o la llamada y, cuando aparece %>%, continúa la transformación. |
| 520 | `# They apply only when currently required or explicitly enabled by the user.` | Comentario: They apply only when currently required or explicitly enabled by the user. |
| 557 | `left_join(adjudication_decisions, by = "paperID") %>%` | Adelanta la unión con los datos manuales: el control debe estar disponible antes de calcular requires_adjudication. |
| 559 | `apply_reviewer3 = coalesce(apply_reviewer3, FALSE),` | Usa FALSE para artículos sin fila manual; una ausencia nunca activa una revisión. |
| 561 | `disagreement_any_variable \| apply_reviewer3,` | Añade la activación explícita como motivo suficiente para aplicar Reviewer 3, manteniendo los motivos automáticos anteriores. |
| 566 | `apply_reviewer3 ~ "Additional manual review",` | Identifica la revisión adicional cuando no hay otro motivo previo; se respeta la prioridad Incomplete, Disagreement y discrepancia de variables. |
| 648 | `pending_decision = (agreement_status %in% c("Disagreement", "Incomplete") \|` | Amplía la condición que exige una decisión de Reviewer 3 para incluir la revisión adicional. |
| 649 | `apply_reviewer3) &` | Una activación explícita exige decisión aunque los revisores iniciales estuvieran de acuerdo; el chequeo existente de NA determina si está pendiente. |
| 690 | `disagreement_any_variable, apply_reviewer3,` | Exporta el control en final_screening para conservarlo entre ejecuciones y permitir auditarlo. |
| 691 | `requires_adjudication, adjudication_reason,` | Mantiene los indicadores calculados junto al control; la separación visual no cambia su significado. |
| 918 | `left_join(adjudication_decisions %>% select(-apply_reviewer3),` | Al recuperar el historial, excluye el control de la tabla derecha porque ya está en el resultado actual; evita columnas .x/.y. |
| 919 | `by = "paperID", suffix = c("", "_historical"))` | Mantiene la recuperación por ID y los sufijos que usa el bucle existente para preservar respuestas históricas. |

## Pruebas y revisión del diff

`Rscript tests/test_reviewer3.R` ejecuta el procesamiento y las exportaciones reales sobre archivos temporales; omite únicamente las figuras. Se conservan las pruebas anteriores y se añaden estos casos:

- ID 13: un revisor Rejected → Reviewer 3 Accepted, prioridad de Topic, recuperación de taxa/arte, conservación de la decisión y criterio iniciales, notas y estado Resolved.
- ID 14: un revisor Accepted → Reviewer 3 Rejected, criterio nuevo y limpieza solo de categorías finales.
- ID 15: activación sin decisión, conservación de la fila y presencia en pendientes y exportaciones.
- ID 16: control vacío y feedback histórico; no se aplica al resultado actual.
- ID 17: dos revisores coincidentes; el histórico no se aplica con FALSE y sí con TRUE.
- Capitalización true, FALSE y vacíos; rechazo explícito de yes.
- Igualdad de dos ejecuciones y de una ejecución que adopta una copia del libro actualizado, incluido el control.
- Hash de la entrada manual intacto y bloqueo de coincidencias entre entrada y salida antes de escribir.
- Libros antiguos sin columna, decisiones incompletas, discrepancias solo de variables y subconjuntos de un solo revisor, ya cubiertos por las pruebas anteriores.

Validación realizada con R 4.4.3 y dplyr 1.2.1. También se comprobó `git diff --check` y se revisó el diff completo: script de screening, pruebas, README y esta guía; sin datos privados ni cambios en la clasificación bibliográfica o el script de lectura de texto completo. No se ha probado separadamente dplyr 1.1.1 ni las figuras.

Se hizo además una prueba local con una copia temporal derivada del Excel de 2.285 artículos y 2.855 revisiones iniciales: se activaron exactamente los 150 IDs de las dos listas, y las 150 decisiones coincidieron con Reviewer 3 (92 Accepted y 58 Rejected; los 150 Resolved). Esta prueba comprueba la integración de decisiones, no la corrección científica de las clasificaciones ni una ejecución sobre los archivos originales Done. Los hashes del libro original y la entrada temporal no cambiaron.

**Bloqueo previo del archivo real:** paperID 757 contiene NOTOPIC como decision_reviewer_3, que solo admite Accepted/Rejected. Primero se verificó que el script se detiene indicando 757; después se excluyó únicamente esa adjudicación inválida de la copia temporal para comprobar las otras decisiones. No se corrigió ni modificó el original. Debe revisarse manualmente antes de ejecutar el archivo real. En esa copia quedaron cuatro pendientes fuera de los 150 IDs; no se ocultaron ni se resolvieron automáticamente.
