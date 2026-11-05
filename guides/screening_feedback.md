# Figuras para la reunión y feedback individual

Ejecutar `source("src/07_screeningFeedback.R")` después del script 05, con `output_data` definido por el setup. También puede ejecutarse después del 06: lee el mismo `abstract_screening/abstract_screening_final.xlsx`, sin editarlo. Las correcciones efectuadas únicamente en las hojas de asignaciones del 06 no aparecen aquí hasta que estén integradas en esa entrada. Requiere readxl, dplyr, tidyr, stringr, ggplot2 y openxlsx.

## Archivos generados

Dentro de `output_data/abstract_screening/feedback_screening/`:

- `figures/figure_1_unique_paper_outcomes.png` y `.pdf`: total de IDs únicos y resultados Accepted/Rejected, con pendientes si los hay. Accepted significa pasar a texto completo; no elegibilidad definitiva.
- `figures/figure_2a_reviewer3_review_routes.png` y `.pdf`: arriba, el grupo completo de artículos con dos revisores iniciales; abajo, el grupo completo con uno. El encabezado indica el total N de cada grupo, aunque no todos sus artículos hayan tenido discrepancias o cambios. Cada panel muestra tres barras: Accepted/Rejected, criterio de rechazo y categorías (Topic/TaxaGroup/fishingGear). En el panel inferior, el segmento naranja añade artículos con un campo inicialmente requerido y vacío que Reviewer 3 completó. Si también cambió un valor del mismo tipo, el artículo cuenta en el segmento de cambios.
- `figures/figure_2b_reviewer3_changes_by_reviewer.png` y `.pdf`: artículos con al menos un valor existente cambiado, por revisor inicial; etiquetas con numerador, carga total y porcentaje. Incluye decisión, criterio y categorías aplicables. No se limita a Accepted/Rejected.
- `figures/figure_3_missing_fields_by_reviewer.png` y `.pdf`: mapa de campos faltantes en las evaluaciones iniciales. Las celdas muestran faltantes/aplicables y el color muestra el porcentaje. n/a significa que no hay evaluaciones aplicables.
- `feedback_<reviewer>.xlsx`: un libro por cada revisor nombrado en la entrada, incluso si no hay casos que corregir.
- `screening_feedback_summary.xlsx`: datos de las figuras, métricas por revisor, cambios de decisión, intervenciones por artículo y comparación detallada de cada campo. `Source` registra la entrada y su hash; `Intervention_totals` da los totales únicos, su solapamiento y la unión sin duplicados.

Los archivos son salidas regenerables: se sobrescriben al ejecutar de nuevo el script. No utilizarlos como entrada de correcciones; estas siguen el flujo del Excel manual de Reviewer 3. Los libros de revisores que ya no aparecen en una nueva entrada no se eliminan automáticamente: `Reviewer_files` identifica los libros de la ejecución actual.

## Cómo se calculan los cambios

Solo cuentan valores aportados por Reviewer 3 cuando `requires_adjudication` está activo en la salida de 05. El historial inactivo no se considera una intervención actual. Una nota o nombre de adjudicador por sí solos tampoco cuentan como cambio de codificación.

Se compara cada evaluación inicial con los valores explícitos de Reviewer 3:

- **changed_value**: había un valor inicial y Reviewer 3 aporta otro diferente.
- **completed_value**: el campo inicial estaba vacío y Reviewer 3 lo completa.
- **missing_initial**: faltaba un dato que correspondía rellenar en esa evaluación inicial, según las reglas acordadas.

La comparación ignora mayúsculas, espacios y orden de selecciones separadas por `/`, `;` o `,`. No fusiona automáticamente sinónimos semánticos. Solo se comparan categorías aplicables al resultado final: criterio para Rejected; Topic y fishingGear para Accepted; TaxaGroup para Accepted de Megafauna catch. La decisión siempre es comparable. No se cuentan como cambios explícitos los vaciados mecánicos de campos finales que efectúa el script 05 tras un rechazo.

En la figura 2a, cada artículo pertenece a un único panel según `n_reviewers`: dos revisores (subconjunto de control) frente a uno. No se clasifica según agreement_status ni apply_reviewer3: los artículos con dos revisores que coincidían también pertenecen al panel superior. N cuenta todos los artículos de ese grupo, no solo los que Reviewer 3 modificó. Rellenar una decisión vacía no cuenta como cambio de una decisión existente. Cada barra cuenta IDs distintos: cambiar dos categorías o corregir a ambos revisores no duplica el artículo dentro de esa barra. Un artículo sí puede contribuir a varias barras (por ejemplo, decisión y criterio); **sumar las barras no da necesariamente artículos distintos**. `Figure2_changes` contiene los seis recuentos y sus denominadores n_total; `Figure2_papers` contiene los IDs que los forman. Los totales de cambios y completados mantienen su posible solapamiento en `Intervention_totals`.

A nivel de revisor se compara su propia evaluación; un artículo compartido puede contribuir al feedback de dos personas. **Sumar los recuentos de todos los revisores no equivale al número de artículos únicos.**

`Reviewer_summary` incluye n_reviewed, n_with_active_reviewer3, n_changed, n_completed, n_intervened, n_missing y los cambios/completados de decisión por separado. Se ofrecen porcentajes sobre toda la carga y sobre el subconjunto con Reviewer 3 activo. `Decision_changes` cuenta evaluaciones iniciales por transición; no artículos únicos.

## Rutas conservadas para auditoría

Estas rutas siguen disponibles en las tablas y el feedback individual, pero ya no se usan como categorías de la figura 2a. Se reconstruyen con los indicadores de la entrada:

| Ruta | Regla |
|---|---|
| Initial disagreement | Disagreement de decisión o alguna discrepancia de variables, sin activación adicional. |
| Incomplete decision | Decisión inicial incompleta, sin discrepancia ni activación adicional. |
| Additional review | apply_reviewer3 TRUE sin incidencia inicial. |
| Initial issue + additional review | Coinciden una incidencia inicial y apply_reviewer3 TRUE. |

La categoría conjunta evita atribuir arbitrariamente los casos solapados a una única causa. Los indicadores **no registran la motivación histórica de la revisión**: las rutas describen los datos disponibles, no prueban por qué se revisó un artículo. No se intenta distinguir una decisión tomada por IA de una validada/corregida por el adjudicador: se usa únicamente la evaluación guardada en Reviewer 3.

## Campos faltantes: reglas acordadas

Se usan la decisión y el Topic de cada evaluación **inicial**, independientemente de lo que Reviewer 3 haya corregido después:

| Campo | Cuándo se esperaba |
|---|---|
| decision | Siempre. |
| TA_exclCriteria | El revisor inicial puso Rejected. |
| Topic | El revisor inicial puso Accepted. |
| fishingGear | El revisor inicial puso Accepted. |
| TaxaGroup | El revisor inicial puso Accepted y su Topic incluye Megafauna catch. |

Con decisión vacía solo se exige decisión; con Topic vacío no se presupone Megafauna catch para exigir taxa. Esto evita inventar la aplicabilidad de otros campos. La figura informa de campos vacíos, no de validez semántica de sus valores. Un TaxaGroup incorrecto pero no vacío no cuenta como faltante.

Estas reglas sirven para el feedback de completitud; **no modifican los requisitos de adjudicación** del 05, donde solo obligan a resolver las variables discrepantes aplicables.

## Qué contiene cada libro individual

- **Summary**: carga de trabajo, artículos modificados/completados, datos faltantes y denominadores.
- **Papers**: únicamente casos con algún cambio, completado o dato inicialmente faltante. Incluye ID, título, resumen, keywords, metadatos disponibles, su evaluación, la de Reviewer 3, resultado final y listas de campos afectados. No incluye el screening de otro revisor.
- **Field_details**: una fila por campo afectado, valor inicial y valor de Reviewer 3, con indicadores de cambio/completado/faltante. Valor nuevo en rojo; vacío inicialmente necesario con fondo amarillo. Los indicadores textuales evitan depender solo del color.
- **Missing_summary**: faltantes y denominadores por campo.

Un campo inicialmente faltante se incluye aunque nadie lo haya completado todavía, o aunque el resultado final ya no requiera esa categoría. Así se conserva el feedback de cómo se rellenó la evaluación original.

## Límites e interpretación para la reunión

Es una comparación de la instantánea actual: si ya se sobrescribieron las evaluaciones originales en los archivos Done, no se puede reconstruir su historia anterior sin una versión de respaldo. Los IDs duplicados semánticamente siguen contando como IDs únicos distintos; este script no cambia la deduplicación pendiente del proyecto.

Los cambios de Reviewer 3 **no son automáticamente errores del revisor inicial**. Incluyen decisiones de adjudicación, casos ambiguos y nuevas comprobaciones del texto completo. El subconjunto revisado por Reviewer 3 está seleccionado; los porcentajes no deben presentarse como estimadores imparciales de una tasa de error ni como ranking de calidad.

Para el feedback de la reunión, conviene acompañar las cifras con dos o tres ejemplos de cambios de criterio y un acuerdo explícito de cómo rellenar cada campo. Las categorías de aceptación/exclusión ya generadas por el 06 pueden añadirse a las diapositivas. Los Accepted de esta salida todavía pueden tener codificación pendiente; el 05 sigue siendo la referencia para adjudication_pending.

## Comprobaciones

`Rscript tests/test_screening_feedback.R` verifica resultados únicos frente a evaluaciones compartidas, prioridad del historial activo/inactivo, separación entre cambios y completados, campos no aplicables, decisión faltante, comparación de selecciones reordenadas, denominadores, exports por revisor, figuras PNG/PDF, conservación del hash de entrada, reejecución y ausencia total de intervenciones. Para la figura 2a comprueba las seis barras, los denominadores sobre todos los artículos de cada grupo, los vacíos completados solo en el panel inferior, los ceros y que dos cambios de categorías o dos revisores corregidos cuentan un solo ID por barra. También comprueba que dos revisores que coincidían siguen perteneciendo al panel superior.

El script no envía los Excel a los revisores. Genera los archivos localmente para que el equipo los examine y decida cómo compartirlos.
