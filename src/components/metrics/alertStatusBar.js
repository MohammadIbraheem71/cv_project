import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

/**
 * AlertStatusBar
 * A full-width colored bar showing the current detection status.
 * Color changes based on alert level:
 *  danger  → red
 *  warning → amber
 *  safe    → green
 *  clear   → neutral
 *
 * Props:
 *  level   - 'danger' | 'warning' | 'safe' | 'clear'
 *  message - string to display
 */
export default function AlertStatusBar({ level, message }) {
  const colors = {
    danger:  { bg: 'rgba(226,75,74,0.2)',   text: '#f97e7e', border: 'rgba(226,75,74,0.4)' },
    warning: { bg: 'rgba(239,159,39,0.2)',  text: '#f5c06a', border: 'rgba(239,159,39,0.4)' },
    safe:    { bg: 'rgba(29,158,117,0.2)',  text: '#7bf6cf', border: 'rgba(29,158,117,0.4)' },
    clear:   { bg: 'rgba(255,255,255,0.05)',text: 'rgba(234,241,255,0.6)', border: 'rgba(255,255,255,0.08)' },
  };

  const c = colors[level] || colors.clear;

  return (
    <View style={[styles.bar, { backgroundColor: c.bg, borderColor: c.border }]}>
      <View style={[styles.dot, { backgroundColor: c.text }]} />
      <Text style={[styles.text, { color: c.text }]}>{message}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    borderRadius: 14,
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  text: {
    fontSize: 14,
    fontWeight: '700',
    flex: 1,
  },
});