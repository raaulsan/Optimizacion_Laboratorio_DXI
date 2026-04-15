# MODELO DE OPTIMIZACIÓN — LABORATORIO DE ANÁLISIS CLÍNICO (DxI-9000)
# =============================================================================
# Asignación de 28 pruebas clínicas a 3 analizadores idénticos DxI-9000 y
# determinación del número de petacas de reactivo por prueba y analizador.
#
# OBJETIVO JERÁRQUICO (lexicográfico):
#   1º  Minimizar el tiempo máximo de procesamiento diario (makespan).
#   2º  Maximizar las co-ocurrencias de pares de pruebas resueltas por un
#       único analizador (reducir fragmentación de peticiones en el carro de cubetas).
#
# VARIABLES:
#   p[i,j]   = nº de petacas de la prueba i en el analizador j  (entero >= 0)
#   x[i,j]   = 1 si la prueba i está disponible en el analizador j  (binaria)
#   y[i,j]   = fracción de la demanda diaria de i enrutada a j  (continua [0,1])
#   w_*[g,j] = 1 si TODAS las pruebas del grupo g están en el analizador j  (binaria)
#   T_max    = makespan: tiempo máximo de procesamiento entre analizadores (horas)
# =============================================================================

# ─── CONJUNTOS ────────────────────────────────────────────────────────────────

set PRUEBAS ordered;          # 28 pruebas clínicas
set ANALIZADORES ordered;     # 3 analizadores DxI-9000

# Subconjuntos clínicos (usados en restricciones y análisis)
set EXENTAS    within PRUEBAS;  # exentas del plan de contingencia (bajo volumen)
set UN_PASO    within PRUEBAS;  # pruebas de 1 paso (450 det/h)
set DOS_PASOS  within PRUEBAS;  # pruebas de 2 pasos (225 det/h)
set BIG_SIX    within PRUEBAS;  # 6 pruebas de mayor volumen: deben estar en los 3 analizadores

# Grupos de co-ocurrencia por nivel (identificadores de grupo)
set GRUPOS_PARE; set GRUPOS_TRIP; set GRUPOS_CUAR; set GRUPOS_QUIN; set GRUPOS_SEXT;

# Pruebas que componen cada grupo
set COMP_PARE {GRUPOS_PARE} within PRUEBAS;
set COMP_TRIP {GRUPOS_TRIP} within PRUEBAS;
set COMP_CUAR {GRUPOS_CUAR} within PRUEBAS;
set COMP_QUIN {GRUPOS_QUIN} within PRUEBAS;
set COMP_SEXT {GRUPOS_SEXT} within PRUEBAS;


# ─── PARÁMETROS ───────────────────────────────────────────────────────────────

param cap  {ANALIZADORES} integer >= 1;  # posiciones disponibles por analizador
param c    {PRUEBAS}      > 0;           # determinaciones por petaca
param vel  {PRUEBAS}      > 0;           # velocidad máxima (det/hora)
param dem  {PRUEBAS}      >= 0;          # demanda media diaria (det/día laborable)
param horas               > 0;           # horas de trabajo disponibles por día

# Parámetro de equilibrio: diferencia máxima de pruebas de 1 paso entre analizadores
param delta integer >= 0 default 3;

# Umbral de demanda por debajo del cual una prueba no debe estar en los 3 analizadores.
# El coste de calibración y control de calidad supera el beneficio de triplicar una prueba
# de muy bajo volumen. Valor por defecto: 20 det/día (indicado por el laboratorio).
param umbral_tri >= 0 default 20;

# Frecuencia de co-ocurrencia por nivel (nº de peticiones en enero donde el grupo aparece completo)
param f_PARE {GRUPOS_PARE} >= 0;
param f_TRIP {GRUPOS_TRIP} >= 0;
param f_CUAR {GRUPOS_CUAR} >= 0;
param f_QUIN {GRUPOS_QUIN} >= 0;
param f_SEXT {GRUPOS_SEXT} >= 0;

# Makespan óptimo de la fase 1 (se actualiza en el run file entre fases)
# Con valor Infinity la restricción MakespanFijado queda inactiva
param T_opt default Infinity;


# ─── VARIABLES ────────────────────────────────────────────────────────────────

var p {PRUEBAS, ANALIZADORES} integer >= 0;        # petacas asignadas
var x {PRUEBAS, ANALIZADORES} binary;              # presencia de prueba en analizador
var y {PRUEBAS, ANALIZADORES} >= 0, <= 1;          # fracción de demanda enrutada
var T_max >= 0;                                     # makespan (horas)

# w_*[g,j] = 1 sii TODAS las pruebas del grupo g están en el analizador j
var w_pare {GRUPOS_PARE, ANALIZADORES} binary;
var w_trip {GRUPOS_TRIP, ANALIZADORES} binary;
var w_cuar {GRUPOS_CUAR, ANALIZADORES} binary;
var w_quin {GRUPOS_QUIN, ANALIZADORES} binary;
var w_sext {GRUPOS_SEXT, ANALIZADORES} binary;


# ─── OBJETIVOS (jerárquicos — se activan por fases en el run file) ────────────
#
# FASE 1 — Minimizar makespan:
#   T_max es el tiempo del analizador más cargado.
#   La carga de j = sum_i [ y[i,j] * dem[i] / vel[i] ]
#
# FASE 2 — Maximizar cohesión jerárquica de peticiones:
#   Para cada grupo g de nivel L y analizador j, w_L[g,j]=1 indica que
#   todas las pruebas del grupo están juntas en j.
#   El objetivo suma, por nivel, la frecuencia del grupo multiplicada por
#   el número de analizadores donde el grupo queda completo.

minimize Makespan: T_max;

maximize Cohesion:
    sum {g in GRUPOS_PARE, j in ANALIZADORES} f_PARE[g] * w_pare[g,j]
  + sum {g in GRUPOS_TRIP, j in ANALIZADORES} f_TRIP[g] * w_trip[g,j]
  + sum {g in GRUPOS_CUAR, j in ANALIZADORES} f_CUAR[g] * w_cuar[g,j]
  + sum {g in GRUPOS_QUIN, j in ANALIZADORES} f_QUIN[g] * w_quin[g,j]
  + sum {g in GRUPOS_SEXT, j in ANALIZADORES} f_SEXT[g] * w_sext[g,j];


# ─── RESTRICCIONES ────────────────────────────────────────────────────────────

# R1: Capacidad de posiciones de reactivo por analizador
#     Suma de petacas usadas <= posiciones disponibles.
#     El llenado completo de posiciones (necesidad operativa del laboratorio)
#     se gestiona en el postproceso proporcional_petacas.py, que distribuye
#     las posiciones sobrantes proporcionalmente a la demanda de cada prueba.
subject to CapacidadPosiciones {j in ANALIZADORES}:
    sum {i in PRUEBAS} p[i,j] <= cap[j];

# R2: Petacas suficientes para cubrir la demanda enrutada al analizador
#     p[i,j] * c[i] >= y[i,j] * dem[i]
#     → cada petaca aporta c[i] determinaciones; si y[i,j] dem[i] se procesan aquí,
#       necesitamos al menos ceil(y[i,j]*dem[i]/c[i]) petacas.
subject to CoberturaDemanda {i in PRUEBAS, j in ANALIZADORES}:
    p[i,j] * c[i] >= y[i,j] * dem[i];

# R3: Toda la demanda diaria de cada prueba debe quedar cubierta
subject to DemandaCompleta {i in PRUEBAS}:
    sum {j in ANALIZADORES} y[i,j] = 1;

# R4: Solo se puede enrutar demanda a un analizador si la prueba está instalada en él
subject to SoloEnrutarSiPresente {i in PRUEBAS, j in ANALIZADORES}:
    y[i,j] <= x[i,j];

# R5a: Coherencia p↔x: si no hay petacas, la prueba no está disponible
#      Cota superior: una prueba no puede usar más posiciones que las del analizador
subject to PetacasImplicanPresencia {i in PRUEBAS, j in ANALIZADORES}:
    p[i,j] <= cap[j] * x[i,j];

# R5b: Coherencia x↔p: si la prueba está asignada, necesita al menos 1 petaca
subject to PresenciaImplicaPetacas {i in PRUEBAS, j in ANALIZADORES}:
    x[i,j] <= p[i,j];

# R6: Plan de contingencia — la mayoría de pruebas deben estar en >= 2 analizadores
#     Excepción: pruebas de muy bajo volumen (EXENTAS) solo necesitan >= 1
subject to Contingencia {i in PRUEBAS diff EXENTAS}:
    sum {j in ANALIZADORES} x[i,j] >= 2;

subject to ContingenciaExentas {i in EXENTAS}:
    sum {j in ANALIZADORES} x[i,j] >= 1;

# R6b: Big Six — las 6 pruebas de mayor volumen deben estar en los 3 analizadores
#      (requisito operativo: garantizar cobertura máxima de la demanda dominante)
subject to BigSixEnTodos {i in BIG_SIX, j in ANALIZADORES}:
    x[i,j] = 1;

# R6c: Pruebas de bajo volumen — no deben ir en los 3 analizadores simultáneamente.
#      El coste de calibración y control de calidad por instalar el reactivo en un tercer
#      equipo supera el beneficio operativo cuando la demanda es muy reducida.
#      Umbral: dem[i] < umbral_tri (por defecto 20 det/día, según criterio del laboratorio).
#      Se excluye el Big Six (ya fijado en R6b) para evitar conflicto de restricciones.
subject to BajoVolumenMaxDos {i in PRUEBAS diff BIG_SIX: dem[i] < umbral_tri}:
    sum {j in ANALIZADORES} x[i,j] <= 2;

# R7: PSAL (PSA libre) siempre debe ir en un analizador donde también esté PSA.
#     PSA puede estar en analizadores sin PSAL (cubre peticiones sin fracción libre).
subject to PSA_PSAL_Sync {j in ANALIZADORES}:
    x['PSAL', j] <= x['PSA', j];

# R8: Definición del makespan — T_max >= carga de cada analizador
subject to MakespanBound {j in ANALIZADORES}:
    sum {i in PRUEBAS} (y[i,j] * dem[i] / vel[i]) <= T_max;

# R9: Equilibrio de pruebas de 1 paso entre analizadores
#     |N1paso_j - N1paso_k| <= delta  ∀ j, k
#     (evita que un analizador acumule demasiadas pruebas lentas de 2 pasos)
subject to EquilibrioUnPasoLE {j in ANALIZADORES, k in ANALIZADORES: ord(j) < ord(k)}:
    sum {i in UN_PASO} x[i,j] - sum {i in UN_PASO} x[i,k] <= delta;

subject to EquilibrioUnPasoGE {j in ANALIZADORES, k in ANALIZADORES: ord(j) < ord(k)}:
    sum {i in UN_PASO} x[i,k] - sum {i in UN_PASO} x[i,j] <= delta;

# R10: El makespan no puede exceder las horas de trabajo disponibles
subject to JornadaLaboral:
    T_max <= horas;

# R11: Fijación del makespan entre fases (inactiva en fase 1 porque T_opt=Infinity)
#      En fase 2 impide que la búsqueda de cohesión empeore el tiempo de procesamiento
subject to MakespanFijado:
    T_max <= T_opt;

# ─── RESTRICCIONES DE LINEALIZACIÓN DE w (grupos) ─────────────────────────────
# w[g,j] = AND_{i in COMP[g]} x[i,j]   (1 sii todas las pruebas del grupo están en j)
# Linealización estándar para AND de n binarias:
#   (Cota superior)  w[g,j] <= x[i,j]                    ∀i∈COMP[g]
#   (Cota inferior)  w[g,j] >= sum_{i∈COMP[g]} x[i,j] − (|COMP[g]|−1)

# PAREJAS (n=2)
subject to Pare_Superior {g in GRUPOS_PARE, i in COMP_PARE[g], j in ANALIZADORES}:
    w_pare[g,j] <= x[i,j];
subject to Pare_Inferior {g in GRUPOS_PARE, j in ANALIZADORES}:
    w_pare[g,j] >= sum {i in COMP_PARE[g]} x[i,j] - 1;

# TRIPLETAS (n=3)
subject to Trip_Superior {g in GRUPOS_TRIP, i in COMP_TRIP[g], j in ANALIZADORES}:
    w_trip[g,j] <= x[i,j];
subject to Trip_Inferior {g in GRUPOS_TRIP, j in ANALIZADORES}:
    w_trip[g,j] >= sum {i in COMP_TRIP[g]} x[i,j] - 2;

# CUARTETOS (n=4)
subject to Cuar_Superior {g in GRUPOS_CUAR, i in COMP_CUAR[g], j in ANALIZADORES}:
    w_cuar[g,j] <= x[i,j];
subject to Cuar_Inferior {g in GRUPOS_CUAR, j in ANALIZADORES}:
    w_cuar[g,j] >= sum {i in COMP_CUAR[g]} x[i,j] - 3;

# QUÍNTUPLOS (n=5)
subject to Quin_Superior {g in GRUPOS_QUIN, i in COMP_QUIN[g], j in ANALIZADORES}:
    w_quin[g,j] <= x[i,j];
subject to Quin_Inferior {g in GRUPOS_QUIN, j in ANALIZADORES}:
    w_quin[g,j] >= sum {i in COMP_QUIN[g]} x[i,j] - 4;

# SÉXTUPLOS (n=6)
subject to Sext_Superior {g in GRUPOS_SEXT, i in COMP_SEXT[g], j in ANALIZADORES}:
    w_sext[g,j] <= x[i,j];
subject to Sext_Inferior {g in GRUPOS_SEXT, j in ANALIZADORES}:
    w_sext[g,j] >= sum {i in COMP_SEXT[g]} x[i,j] - 5;
