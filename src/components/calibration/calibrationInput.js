import React from 'react';
import { View, Text, TextInput, StyleSheet } from 'react-native';

/**
 * CalibrationInput
 * A labeled numeric input row used inside CalibrationPanel.
 *
 * Props:
 *  label    - string: field label
 *  value    - number: current value
 *  onChange - (number) => void
 *  hint     - string: small hint text below input (optional)
 */
export default function CalibrationInput({ label, value, onChange, hint }) {
  return (
    <View style={styles.wrapper}>
      <View style={styles.row}>
        <Text style={styles.label}>{label}</Text>
        <TextInput
          style={styles.input}
          keyboardType="numeric"
          value={String(value)}
          onChangeText={(v) => {
            const parsed = parseFloat(v);
            if (!isNaN(parsed) && parsed > 0) onChange(parsed);
          }}
          placeholderTextColor="rgba(234,241,255,0.3)"
          selectTextOnFocus
        />
      </View>
      {hint ? <Text style={styles.hint}>{hint}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    gap: 4,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  label: {
    flex: 1,
    color: 'rgba(234, 241, 255, 0.75)',
    fontSize: 14,
  },
  input: {
    backgroundColor: 'rgba(255,255,255,0.08)',
    color: '#ffffff',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
    width: 90,
    textAlign: 'center',
    fontSize: 14,
    fontWeight: '700',
  },
  hint: {
    color: 'rgba(234, 241, 255, 0.4)',
    fontSize: 11,
    marginLeft: 2,
  },
});