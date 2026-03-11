const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

const router = express.Router();

// Mock database
const metrics = {};

// Record call metrics
router.post('/call/:callId', asyncHandler(async (req, res) => {
  const { callId } = req.params;
  const {
    videoResolution,
    frameRate,
    bitrate,
    latency,
    packetLoss,
    bandwidth,
    jitterBuffer,
    audioLevel,
    videoCodec,
    audioCodec,
    networkType
  } = req.body;

  if (!metrics[callId]) {
    metrics[callId] = {
      callId,
      metricsHistory: [],
      qualityScore: 0
    };
  }

  const metricEntry = {
    timestamp: new Date(),
    videoResolution,
    frameRate,
    bitrate,
    latency,
    packetLoss,
    bandwidth,
    jitterBuffer,
    audioLevel,
    videoCodec,
    audioCodec,
    networkType,
    qualityScore: calculateQualityScore({
      videoResolution,
      frameRate,
      latency,
      packetLoss,
      bandwidth
    })
  };

  metrics[callId].metricsHistory.push(metricEntry);

  // Keep only last 100 entries
  if (metrics[callId].metricsHistory.length > 100) {
    metrics[callId].metricsHistory.shift();
  }

  metrics[callId].qualityScore = metricEntry.qualityScore;

  logger.info(`Metrics recorded for call ${callId}`, metricEntry);

  res.json({
    callId,
    message: 'Metrics recorded',
    qualityScore: metricEntry.qualityScore,
    metric: metricEntry
  });
}));

// Get call metrics
router.get('/call/:callId', asyncHandler(async (req, res) => {
  const { callId } = req.params;
  const callMetrics = metrics[callId];

  if (!callMetrics) {
    return res.status(404).json({ error: 'No metrics found for this call' });
  }

  const averages = calculateAverages(callMetrics.metricsHistory);

  res.json({
    callId,
    qualityScore: callMetrics.qualityScore,
    averages,
    recentMetrics: callMetrics.metricsHistory.slice(-10).reverse()
  });
}));

// Get user call statistics
router.get('/user/stats', asyncHandler(async (req, res) => {
  const userId = req.user.userId;

  // Calculate stats
  const userCallMetrics = Object.values(metrics).filter(m => {
    // In production, filter by user
    return true;
  });

  const totalCalls = userCallMetrics.length;
  const avgQualityScore = userCallMetrics.reduce((sum, m) => sum + m.qualityScore, 0) / totalCalls || 0;
  const callsWithExcellentQuality = userCallMetrics.filter(m => m.qualityScore >= 8).length;
  const callsWithPoorQuality = userCallMetrics.filter(m => m.qualityScore < 5).length;

  res.json({
    userId,
    totalCalls,
    avgQualityScore: parseFloat(avgQualityScore.toFixed(2)),
    callsWithExcellentQuality,
    callsWithPoorQuality,
    qualityScoreTrend: 'improving' // In production, calculate trend
  });
}));

// Network performance report
router.get('/network/performance', asyncHandler(async (req, res) => {
  const { days = 7 } = req.query;
  const userId = req.user.userId;

  // Aggregate all metrics
  const allMetrics = [];
  Object.values(metrics).forEach(m => {
    allMetrics.push(...m.metricsHistory);
  });

  const networkStats = {
    avgBandwidth: allMetrics.reduce((sum, m) => sum + m.bandwidth, 0) / allMetrics.length || 0,
    avgLatency: allMetrics.reduce((sum, m) => sum + m.latency, 0) / allMetrics.length || 0,
    avgPacketLoss: allMetrics.reduce((sum, m) => sum + m.packetLoss, 0) / allMetrics.length || 0,
    networkTypeDistribution: getNetworkTypeDistribution(allMetrics),
    commonResolutions: getCommonResolutions(allMetrics),
    timeSeriesData: aggregateByHour(allMetrics)
  };

  res.json({
    period: `Last ${days} days`,
    stats: networkStats
  });
}));

// Helper functions
function calculateQualityScore(metrics) {
  let score = 100;

  // Resolution impact
  const resolutionMap = {
    '1080p': 0,
    '720p': 5,
    '480p': 15,
    '360p': 25,
    '240p': 40
  };
  score -= resolutionMap[metrics.videoResolution] || 0;

  // Frame rate impact
  if (metrics.frameRate < 24) score -= 15;
  if (metrics.frameRate < 15) score -= 10;

  // Latency impact
  if (metrics.latency > 200) score -= 20;
  if (metrics.latency > 400) score -= 15;
  if (metrics.latency > 100) score -= 10;

  // Packet loss impact
  if (metrics.packetLoss > 5) score -= 25;
  if (metrics.packetLoss > 2) score -= 15;
  if (metrics.packetLoss > 1) score -= 10;

  // Bandwidth impact
  if (metrics.bandwidth < 0.5) score -= 30;
  if (metrics.bandwidth < 1) score -= 20;
  if (metrics.bandwidth < 2) score -= 10;

  return Math.max(0, Math.min(100, score));
}

function calculateAverages(metricsArray) {
  if (metricsArray.length === 0) {
    return {};
  }

  const avg = {
    bitrate: metricsArray.reduce((sum, m) => sum + m.bitrate, 0) / metricsArray.length,
    latency: metricsArray.reduce((sum, m) => sum + m.latency, 0) / metricsArray.length,
    packetLoss: metricsArray.reduce((sum, m) => sum + m.packetLoss, 0) / metricsArray.length,
    bandwidth: metricsArray.reduce((sum, m) => sum + m.bandwidth, 0) / metricsArray.length,
    qualityScore: metricsArray.reduce((sum, m) => sum + m.qualityScore, 0) / metricsArray.length
  };

  Object.keys(avg).forEach(key => {
    avg[key] = parseFloat(avg[key].toFixed(2));
  });

  return avg;
}

function getNetworkTypeDistribution(metricsArray) {
  const distribution = {};
  metricsArray.forEach(m => {
    distribution[m.networkType] = (distribution[m.networkType] || 0) + 1;
  });
  return distribution;
}

function getCommonResolutions(metricsArray) {
  const resolutions = {};
  metricsArray.forEach(m => {
    resolutions[m.videoResolution] = (resolutions[m.videoResolution] || 0) + 1;
  });
  return resolutions;
}

function aggregateByHour(metricsArray) {
  const hourly = {};
  metricsArray.forEach(m => {
    const hour = new Date(m.timestamp).toISOString().slice(0, 13);
    if (!hourly[hour]) {
      hourly[hour] = [];
    }
    hourly[hour].push(m);
  });

  const timeSeries = Object.entries(hourly).map(([hour, metrics]) => ({
    hour,
    avgQuality: calculateAverages(metrics).qualityScore,
    callCount: metrics.length
  }));

  return timeSeries.sort((a, b) => new Date(a.hour) - new Date(b.hour));
}

module.exports = router;
