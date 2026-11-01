<?php
declare(strict_types=1);

namespace MedQuest;

use PDO;

/** Reads cases from the website's existing tables (adapt the SQL to your schema). */
final class CaseRepository
{
    public function __construct(private PDO $db) {}

    /** @return int[]|null  correct choice ids, or null if the case does not exist */
    public function correctChoiceIds(int $caseId): ?array
    {
        $st = $this->db->prepare('SELECT id, is_correct FROM case_choices WHERE case_id = ?');
        $st->execute([$caseId]);
        $rows = $st->fetchAll();
        if (!$rows) {
            return null;
        }
        $ids = [];
        foreach ($rows as $r) {
            if ((int) $r['is_correct'] === 1) {
                $ids[] = (int) $r['id'];
            }
        }
        return $ids;
    }

    /**
     * Full case objects (with is_correct and explanation) in the order of $ids.
     * Callers must only pass ids the user is entitled to see.
     */
    public function findFull(array $ids): array
    {
        if (!$ids) {
            return [];
        }
        $ids = array_values(array_map('intval', $ids));
        $in = implode(',', array_fill(0, count($ids), '?'));

        $st = $this->db->prepare(
            "SELECT id, title, category, statement, explanation FROM cases WHERE id IN ($in)"
        );
        $st->execute($ids);
        $byId = [];
        foreach ($st->fetchAll() as $c) {
            $byId[(int) $c['id']] = [
                'id' => (int) $c['id'],
                'title' => $c['title'],
                'category' => $c['category'],
                'statement' => $c['statement'],
                'explanation' => $c['explanation'],
                'choices' => [],
            ];
        }

        $st = $this->db->prepare(
            "SELECT id, case_id, text, is_correct FROM case_choices
             WHERE case_id IN ($in) ORDER BY position, id"
        );
        $st->execute($ids);
        foreach ($st->fetchAll() as $ch) {
            $byId[(int) $ch['case_id']]['choices'][] = [
                'id' => (int) $ch['id'],
                'text' => $ch['text'],
                'is_correct' => (int) $ch['is_correct'] === 1,
            ];
        }

        $out = [];
        foreach ($ids as $id) {
            if (isset($byId[$id])) {
                $out[] = $byId[$id];
            }
        }
        return $out;
    }
}
