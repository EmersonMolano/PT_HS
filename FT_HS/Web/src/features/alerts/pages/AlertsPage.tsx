import { useEffect, useState } from 'react';
import { AlertTriangle, Bell, CheckCircle2, Plus, Save, Trash2 } from 'lucide-react';
import { toast } from 'sonner';
import { alertsApi } from '@shared/http/httpClient';
import { Badge } from '@shared/ui/badge';
import { Button } from '@shared/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@shared/ui/card';
import { Input } from '@shared/ui/input';
import { Label } from '@shared/ui/label';

type AlertStatus = 'Pending' | 'Sent' | 'Read' | 'Dismissed';
type RuleType = 'daily_limit' | 'monthly_limit' | 'excessive_consumption' | 'leak_detected' | 'no_reading';
type CustomRuleType = Extract<RuleType, 'excessive_consumption' | 'leak_detected' | 'no_reading'>;

type AlertEvent = {
  alertId: string;
  message?: string;
  detectedValue?: number | null;
  generatedAt: string;
  status: AlertStatus;
};

type AlertRule = {
  ruleId: string;
  alertType: RuleType;
  threshold: number;
  unit: 'm3_day' | 'm3_month' | 'minutes';
  active: boolean;
};

type ThresholdConfiguration = {
  dailyLimit: number | null;
  monthlyLimit: number | null;
  active: boolean;
};

type RuleDraft = { threshold: string; active: boolean };

const RULE_LABELS: Record<RuleType, string> = {
  daily_limit: 'Límite diario de consumo',
  monthly_limit: 'Límite mensual de consumo',
  excessive_consumption: 'Consumo elevado en un día',
  leak_detected: 'Posible fuga',
  no_reading: 'Dispositivo sin lecturas',
};

const RULE_UNITS: Record<RuleType, AlertRule['unit']> = {
  daily_limit: 'm3_day',
  monthly_limit: 'm3_month',
  excessive_consumption: 'm3_day',
  leak_detected: 'minutes',
  no_reading: 'minutes',
};

const UNIT_LABELS: Record<AlertRule['unit'], string> = {
  m3_day: 'm³ por día',
  m3_month: 'm³ por mes',
  minutes: 'minutos',
};

const CUSTOM_RULE_TYPES: CustomRuleType[] = [
  'excessive_consumption',
  'leak_detected',
  'no_reading',
];

function asThreshold(value: number | null | undefined) {
  return value == null ? '' : String(value);
}

export function NotificationsPanel({ homeId }: { homeId?: string }) {
  const [alerts, setAlerts] = useState<AlertEvent[]>([]);
  const [rules, setRules] = useState<AlertRule[]>([]);
  const [ruleDrafts, setRuleDrafts] = useState<Record<string, RuleDraft>>({});
  const [thresholds, setThresholds] = useState<ThresholdConfiguration | null>(null);
  const [thresholdDraft, setThresholdDraft] = useState({ dailyLimit: '', monthlyLimit: '', active: true });
  const [pendingCount, setPendingCount] = useState(0);
  const [newRuleType, setNewRuleType] = useState<CustomRuleType>('excessive_consumption');
  const [newRuleThreshold, setNewRuleThreshold] = useState('1');
  const [loading, setLoading] = useState(true);
  const [savingThresholds, setSavingThresholds] = useState(false);
  const [savingRuleId, setSavingRuleId] = useState<string | null>(null);
  const [creatingRule, setCreatingRule] = useState(false);

  const load = async () => {
    if (!homeId) {
      setAlerts([]);
      setRules([]);
      setThresholds(null);
      setPendingCount(0);
      setLoading(false);
      return;
    }

    setLoading(true);
    try {
      const [historyResponse, thresholdResponse, pendingResponse, rulesResponse] = await Promise.all([
        alertsApi.history(homeId, 'pageSize=100'),
        alertsApi.thresholds(homeId),
        alertsApi.pending(homeId),
        alertsApi.rules(homeId),
      ]);
      const history = historyResponse.data as AlertEvent[];
      const config = (thresholdResponse.data || null) as ThresholdConfiguration | null;
      const loadedRules = (rulesResponse.data || []) as AlertRule[];

      setAlerts(history);
      setThresholds(config);
      setThresholdDraft({
        dailyLimit: asThreshold(config?.dailyLimit),
        monthlyLimit: asThreshold(config?.monthlyLimit),
        active: config?.active ?? true,
      });
      setPendingCount(Number(pendingResponse.data.pendingCount || 0));
      setRules(loadedRules);
      setRuleDrafts(Object.fromEntries(
        loadedRules.map((rule) => [rule.ruleId, { threshold: String(rule.threshold), active: rule.active }])
      ));
      const nextRuleType = CUSTOM_RULE_TYPES.find((type) => !loadedRules.some((rule) => rule.alertType === type));
      if (nextRuleType && loadedRules.some((rule) => rule.alertType === newRuleType)) {
        setNewRuleType(nextRuleType);
        setNewRuleThreshold(nextRuleType === 'excessive_consumption' ? '1' : '30');
      }
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'No se pudieron cargar las alertas');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, [homeId]);

  const mark = async (alertId: string, status: 'Read' | 'Dismissed') => {
    try {
      await alertsApi.updateStatus(alertId, status);
      toast.success(status === 'Read' ? 'Alerta marcada como leída' : 'Alerta atendida');
      await load();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'No se pudo actualizar la alerta');
    }
  };

  const saveThresholds = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!homeId) return;

    const dailyLimit = thresholdDraft.dailyLimit.trim() === '' ? undefined : Number(thresholdDraft.dailyLimit);
    const monthlyLimit = thresholdDraft.monthlyLimit.trim() === '' ? undefined : Number(thresholdDraft.monthlyLimit);
    const values = [dailyLimit, monthlyLimit].filter((value): value is number => value !== undefined);
    if (!values.length || values.some((value) => !Number.isFinite(value) || value < 0)) {
      toast.error('Indica al menos un límite válido, igual o mayor que cero.');
      return;
    }

    setSavingThresholds(true);
    try {
      await alertsApi.saveThresholds(homeId, {
        dailyLimit,
        monthlyLimit,
        active: thresholdDraft.active,
      });
      toast.success('Límites guardados; las reglas de lectura quedaron sincronizadas.');
      await load();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'No se pudieron guardar los límites');
    } finally {
      setSavingThresholds(false);
    }
  };

  const saveRule = async (rule: AlertRule) => {
    const draft = ruleDrafts[rule.ruleId];
    const threshold = Number(draft?.threshold);
    const minimum = rule.unit === 'minutes' ? Number.MIN_VALUE : 0;
    if (!Number.isFinite(threshold) || threshold < minimum) {
      toast.error(rule.unit === 'minutes' ? 'El umbral debe ser mayor que cero.' : 'El umbral no puede ser negativo.');
      return;
    }

    setSavingRuleId(rule.ruleId);
    try {
      await alertsApi.updateRule(rule.ruleId, {
        alertType: rule.alertType,
        unit: rule.unit,
        threshold,
        active: draft.active,
      });
      toast.success('Regla actualizada');
      await load();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'No se pudo actualizar la regla');
    } finally {
      setSavingRuleId(null);
    }
  };

  const createRule = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!homeId) return;
    const threshold = Number(newRuleThreshold);
    const minimum = RULE_UNITS[newRuleType] === 'minutes' ? Number.MIN_VALUE : 0;
    if (!Number.isFinite(threshold) || threshold < minimum) {
      toast.error(RULE_UNITS[newRuleType] === 'minutes' ? 'El umbral debe ser mayor que cero.' : 'El umbral no puede ser negativo.');
      return;
    }

    setCreatingRule(true);
    try {
      await alertsApi.createRule(homeId, {
        alertType: newRuleType,
        threshold,
        unit: RULE_UNITS[newRuleType],
        active: true,
      });
      toast.success('Regla de alerta creada');
      setNewRuleThreshold(newRuleType === 'excessive_consumption' ? '1' : '30');
      await load();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'No se pudo crear la regla');
    } finally {
      setCreatingRule(false);
    }
  };

  const deleteRule = async (rule: AlertRule) => {
    if (!window.confirm(`¿Eliminar la regla «${RULE_LABELS[rule.alertType]}»?`)) return;
    try {
      await alertsApi.deleteRule(rule.ruleId);
      toast.success('Regla eliminada');
      await load();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'No se pudo eliminar la regla');
    }
  };

  if (!homeId) {
    return <p className="rounded-lg border bg-white p-6 text-sm text-gray-600">Selecciona o crea un hogar para configurar sus alertas.</p>;
  }

  const availableRuleTypes = CUSTOM_RULE_TYPES.filter(
    (type) => !rules.some((rule) => rule.alertType === type)
  );

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle><Bell className="mr-2 inline size-5" />Alertas</CardTitle>
          <CardDescription>Configura los límites y reglas de este hogar. Las lecturas nuevas se evalúan al guardarse.</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div className="rounded-lg border p-4">
              <p className="text-sm text-gray-600">Alertas pendientes</p>
              <p className="text-2xl font-semibold">{pendingCount}</p>
            </div>
            <div className="rounded-lg border p-4">
              <p className="text-sm text-gray-600">Límite diario</p>
              <p className="text-2xl">{thresholds?.dailyLimit == null ? '—' : `${thresholds.dailyLimit} m³`}</p>
            </div>
            <div className="rounded-lg border p-4">
              <p className="text-sm text-gray-600">Límite mensual</p>
              <p className="text-2xl">{thresholds?.monthlyLimit == null ? '—' : `${thresholds.monthlyLimit} m³`}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Límites de consumo</CardTitle>
          <CardDescription>Al superar un límite, la siguiente lectura puede generar una alerta. Deja un campo vacío para desactivar ese límite.</CardDescription>
        </CardHeader>
        <CardContent>
          <form className="space-y-5" onSubmit={saveThresholds}>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="daily-alert-limit">Consumo máximo diario (m³)</Label>
                <Input id="daily-alert-limit" type="number" min="0" step="0.01" value={thresholdDraft.dailyLimit} onChange={(event) => setThresholdDraft((current) => ({ ...current, dailyLimit: event.target.value }))} placeholder="Ej. 0.50" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="monthly-alert-limit">Consumo máximo mensual (m³)</Label>
                <Input id="monthly-alert-limit" type="number" min="0" step="0.01" value={thresholdDraft.monthlyLimit} onChange={(event) => setThresholdDraft((current) => ({ ...current, monthlyLimit: event.target.value }))} placeholder="Ej. 15.00" />
              </div>
            </div>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" checked={thresholdDraft.active} onChange={(event) => setThresholdDraft((current) => ({ ...current, active: event.target.checked }))} />
              Activar límites diarios y mensuales
            </label>
            {!thresholds && <p className="text-sm text-amber-700">Este hogar todavía no tiene valores iniciales. Configura al menos un límite y guárdalo.</p>}
            <Button type="submit" disabled={savingThresholds || loading}>
              <Save className="mr-2 size-4" />{savingThresholds ? 'Guardando…' : 'Guardar límites'}
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Reglas adicionales</CardTitle>
          <CardDescription>Agrega reglas para detectar consumo elevado, posibles fugas o falta de lecturas.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-5">
          {availableRuleTypes.length ? <form onSubmit={createRule} className="grid gap-3 rounded-lg border p-4 sm:grid-cols-[minmax(0,1fr)_180px_auto] sm:items-end">
            <div className="space-y-2">
              <Label htmlFor="new-alert-rule">Tipo de regla</Label>
              <select id="new-alert-rule" className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm" value={newRuleType} onChange={(event) => {
                const selected = event.target.value as CustomRuleType;
                setNewRuleType(selected);
                setNewRuleThreshold(selected === 'excessive_consumption' ? '1' : '30');
              }}>
                {availableRuleTypes.map((type) => <option key={type} value={type}>{RULE_LABELS[type]}</option>)}
              </select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="new-alert-threshold">Umbral ({UNIT_LABELS[RULE_UNITS[newRuleType]]})</Label>
              <Input id="new-alert-threshold" type="number" min={RULE_UNITS[newRuleType] === 'minutes' ? '0.01' : '0'} step="0.01" value={newRuleThreshold} onChange={(event) => setNewRuleThreshold(event.target.value)} required />
            </div>
            <Button type="submit" disabled={creatingRule || loading}><Plus className="mr-2 size-4" />{creatingRule ? 'Creando…' : 'Agregar regla'}</Button>
          </form> : <p className="rounded-lg border p-4 text-sm text-gray-600">Ya están creadas las reglas adicionales disponibles. Puedes ajustar, activar o eliminar cada una aquí.</p>}

          <div className="space-y-3">
            {rules.map((rule) => {
              const isLimit = rule.alertType === 'daily_limit' || rule.alertType === 'monthly_limit';
              const draft = ruleDrafts[rule.ruleId] || { threshold: String(rule.threshold), active: rule.active };
              const enabled = isLimit ? Boolean(thresholds?.active) && rule.active : draft.active;
              return (
                <div key={rule.ruleId} className="flex flex-wrap items-center gap-3 rounded-lg border p-4">
                  <div className="min-w-48 flex-1">
                    <p className="font-medium">{RULE_LABELS[rule.alertType]}</p>
                    <p className="text-sm text-gray-500">{isLimit ? 'Se configura en Límites de consumo' : UNIT_LABELS[rule.unit]}</p>
                  </div>
                  {isLimit ? (
                    <Badge>{enabled ? 'Activa' : 'Inactiva'}</Badge>
                  ) : (
                    <>
                      <Input aria-label={`Umbral: ${RULE_LABELS[rule.alertType]}`} className="w-32" type="number" min={rule.unit === 'minutes' ? '0.01' : '0'} step="0.01" value={draft.threshold} onChange={(event) => setRuleDrafts((current) => ({ ...current, [rule.ruleId]: { ...draft, threshold: event.target.value } }))} />
                      <label className="flex items-center gap-2 text-sm">
                        <input type="checkbox" checked={draft.active} onChange={(event) => setRuleDrafts((current) => ({ ...current, [rule.ruleId]: { ...draft, active: event.target.checked } }))} />
                        Activa
                      </label>
                      <Button type="button" size="sm" variant="outline" disabled={savingRuleId === rule.ruleId} onClick={() => void saveRule(rule)}><Save className="mr-1 size-4" />Guardar</Button>
                      <Button type="button" size="sm" variant="outline" aria-label={`Eliminar ${RULE_LABELS[rule.alertType]}`} onClick={() => void deleteRule(rule)}><Trash2 className="size-4" /></Button>
                    </>
                  )}
                </div>
              );
            })}
            {!loading && !rules.length && <p className="text-sm text-gray-500">No hay reglas cargadas para este hogar.</p>}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Historial de alertas</CardTitle>
          <CardDescription>Consulta las alertas generadas y marca las pendientes como leídas o atendidas.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          {loading ? <p className="text-sm text-gray-500">Cargando alertas…</p> : alerts.length ? (
            alerts.map((alert) => (
              <div key={alert.alertId} className="flex flex-wrap items-center justify-between gap-3 rounded-lg border p-4">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="mt-1 size-5 text-orange-600" />
                  <div>
                    <p className="font-medium">{alert.message || 'Alerta sin descripción'}</p>
                    <p className="text-sm text-gray-500">{new Date(alert.generatedAt).toLocaleString('es-CO')} · valor: {alert.detectedValue ?? '—'}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <Badge>{alert.status}</Badge>
                  {alert.status === 'Pending' && <>
                    <Button size="sm" variant="outline" onClick={() => void mark(alert.alertId, 'Read')}><CheckCircle2 className="mr-1 size-4" />Leída</Button>
                    <Button size="sm" onClick={() => void mark(alert.alertId, 'Dismissed')}>Atender</Button>
                  </>}
                </div>
              </div>
            ))
          ) : <p className="text-sm text-gray-500">No hay alertas para mostrar.</p>}
        </CardContent>
      </Card>
    </div>
  );
}
