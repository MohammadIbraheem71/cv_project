import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

/**
 * MetricsBar
 * Displays three metric cards side by side:
 *  - Distance (m)
 *  - Closing speed (m/s)
 *  - Time to impact (s)
 *
 * Props:
 *  distance - number|null
 *  speed    - number|null
 *  tti      - number|null
 */
export default function MetricsBar({ distance, speed, tti }) {
  return (
    <View style={styles.row}>
      <MetricCard
        label="Distance"
        value={distance !== null ? distance.toFixed(2) : '--'}
        unit="m"
      />
      <MetricCard
        label="Closing speed"
        value={speed !== null ? speed.toFixed(2) : '--'}
        unit="m/s"
      />
      <MetricCard
        label="Time to impact"
        value={tti !== null ? tti.toFixed(1) : '--'}
        unit="s"
      />
    </View>
  );
}

function MetricCard({ label, value, unit }) {
  return (
    <View style={styles.card}>
      <Text style={styles.label}>{label}</Text>
      <Text style={styles.value}>{value}</Text>
      <Text style={styles.unit}>{unit}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: 10,
  },
  card: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: 16,
    padding: 12,
    alignItems: 'center',
  },
  label: {
    color: 'rgba(234, 241, 255, 0.6)',
    fontSize: 11,
    marginBottom: 4,
    textAlign: 'center',
  },
  value: {
    color: '#ffffff',
    fontSize: 22,
    fontWeight: '800',
  },
  unit: {
    color: 'rgba(234, 241, 255, 0.5)',
    fontSize: 11,
    marginTop: 2,
  },
});