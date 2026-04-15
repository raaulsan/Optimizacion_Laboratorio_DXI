# 🏥 Optimización de Laboratorio Clínico — Analizadores DxI-9000

[![AMPL](https://img.shields.io/badge/Modeling-AMPL-red.svg)](https://ampl.com/)
[![Python](https://img.shields.io/badge/Preprocessing-Python-blue.svg)](https://www.python.org/)
[![HiGHS](https://img.shields.io/badge/Solver-HiGHS-brightgreen.svg)](https://highs.dev/)
[![Status](https://img.shields.io/badge/Status-Project%20Completed-success.svg)]()

Este repositorio contiene el desarrollo de un modelo de **Programación Lineal Entera Mixta (MILP)** diseñado para optimizar la carga de trabajo y la cohesión de pruebas en tres analizadores de inmunodiagnóstico **Beckman Coulter DxI-9000**.

---

##  Descripción del Problema

El laboratorio procesa una demanda diaria de **28 pruebas clínicas**. El reto operativo consiste en asignar estas pruebas a los analizadores disponibles minimizando el tiempo de respuesta y, simultáneamente, maximizando la calidad del servicio mediante la reducción de la fragmentación de las muestras.

### Desafíos clave:
* **Gestión del "Big 6":** Pruebas de volumen masivo (TSH, FOL, VITD, B12, T4L, PSA) que saturan los equipos.
* **Pruebas de Especialidad:** Grupos de pruebas que suelen solicitarse juntas (perfiles hormonales, marcadores tumorales) y que deben co-ubicarse para evitar que un tubo viaje entre máquinas.
* **Restricciones Operativas:** Capacidad de 144 posiciones de reactivo, planes de contingencia (duplicidad de pruebas) y equilibrio de velocidades (pruebas de 1-paso vs 2-pasos).

---

##  Metodología: Optimización Lexicográfica

El modelo se resuelve en dos fases jerárquicas utilizando el solver de alto rendimiento **HiGHS**:

### Fase 1: Minimización del Makespan ($T_{max}$)
Se busca el equilibrio de carga perfecto. El objetivo es minimizar el tiempo de procesamiento del analizador más cargado para asegurar que todos los resultados estén listos en el menor tiempo posible (objetivo fijado en las 8 horas de jornada laboral).

### Fase 2: Maximización de la Cohesión
Manteniendo el tiempo óptimo de la Fase 1, el modelo utiliza una **linealización de McCormick** para maximizar la co-ubicación de agrupaciones de especialidad. El análisis incluye:
* **Pares, Tripletas, Cuartetos, Quíntuplos y Séxtuplos** de alta frecuencia.
* Filtrado previo del "Big 6" en Python para centrar la cohesión en las pruebas donde realmente aporta valor clínico (Especialidad).

---

##  Estructura del Proyecto

* `preprocesamiento_laboratorio.ipynb`: Limpieza de datos, binarización de peticiones y cálculo de matrices de co-ocurrencia con **Pandas/NumPy**.
* `modelo_dxi.mod`: Formulación matemática en **AMPL** (variables, objetivos y restricciones).
* `datos_dxi.dat`: Archivo de datos con la demanda real de enero de 2026, capacidades y conjuntos de componentes.
* `run_dxi.run`: Script de ejecución que automatiza las fases y exporta los resultados a un informe de texto.
* `Memoria_Proy_LabOpt.pdf`: Documentación detallada con la justificación clínica, técnica y análisis de resultados.

---

##  Requisitos e Instalación

1.  **AMPL:** Es necesario tener instalado el entorno de modelado AMPL.
2.  **Solver HiGHS:** El modelo utiliza `option solver highs;`.
3.  **Python 3.12+:** Para ejecutar el notebook de preprocesamiento.

```bash
# Para ejecutar el modelo completo desde la consola de AMPL:
ampl: include run_dxi.run;
```
## QUE DEVUELVE EL RUN

La ejecución produce la siguiente salida por terminal:

1. **Fase 1 — Makespan**: resolución del problema de equilibrio de carga. Resultado: makespan óptimo de **2,87 horas (172,2 minutos)**, con los tres analizadores equilibrados al 35,9% de la jornada laboral.

2. **Asignación detallada**: tabla por analizador con las pruebas asignadas, número de petacas, fracción de demanda cubierta y tiempo de procesamiento en minutos.

3. **Tabla de contingencia**: resumen de la presencia de cada prueba en los analizadores, indicando cuáles disponen de plan de contingencia.

4. **Fase 2 — Cohesión**: maximización de la co-ubicación de grupos de pruebas, manteniendo el makespan fijado. Resultado: **99,7% de cohesión** (25.804 de 25.872 co-ocurrencias mensuales cubiertas por un solo analizador).

5. **Tabla final de 144 posiciones**: distribución completa tras el postproceso proporcional, con las 144 posiciones de los tres analizadores ocupadas.

6. **Fichero exportado**: se genera automáticamente `result_xyp.txt` con los valores de todas las variables de decisión.

---
## 🤝 Contribuidores

* **Álvaro Espejo Martínez** - [![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/espejomartinezalvaro-spec)
* **Javier Hernández Rosique** - [![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/javierhernandezrosique)   
* **Raúl Sánchez Ibáñez** - [![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/raaulsan)


