// lib/widgets/dashboard/top_agents_section.dart

import 'package:flutter/material.dart';
import '../../models/dashboard_data.dart';

class TopAgentsSection extends StatelessWidget {
  final List<AgentPerformance> agents;

  const TopAgentsSection({super.key, required this.agents});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: const Color(0xFFF59E0B),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Top 5 Agents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: agents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final agent = agents[index];
              return _buildAgentItem(context, agent);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAgentItem(BuildContext context, AgentPerformance agent) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Rank badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _getRankColor(agent.rank).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${agent.rank}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getRankColor(agent.rank),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Avatar
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(
            agent.name.split(' ').map((e) => e[0]).take(2).join(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Name and code
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agent.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                agent.code,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Performance indicator
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  size: 14,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  '${agent.performanceRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: agent.performanceRate / 100,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getPerformanceColor(agent.performanceRate),
                  ),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFF59E0B); // Gold
      case 2:
        return const Color(0xFF94A3B8); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getPerformanceColor(double rate) {
    if (rate >= 95) return const Color(0xFF10B981);
    if (rate >= 90) return const Color(0xFF3B82F6);
    return const Color(0xFFF59E0B);
  }
}
