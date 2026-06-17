import React from "react";
import { Box } from "@mui/material";
import { useDispatch, useSelector } from "react-redux";
import * as actions from "../actions";
import * as selectors from "../selectors";
import "./CrosswordCell.css";

const CrosswordCell = ({ cell, row, col, language, inputRefs }) => {
  const dispatch = useDispatch();

  const cells = useSelector(selectors.getCrosswordCells);
  const words = useSelector(selectors.getCrosswordWords);
  const wordValidation = useSelector(selectors.getWordValidation);
  const activeWordId = useSelector(selectors.getActiveWordId);

  if (!cell) {
    return <Box className="crossword-placeholder" />;
  }

  const updatedCell = cells?.find(c => c.id === cell.id) || cell;
  const value = updatedCell.userInput || "";

  // Todas las palabras asociadas a esta celda
  const wordIds = updatedCell.crosswordCellWordLinkDtoList?.map(link => link.wordId) || [];

  // ✅ Color feedback
  const showCorrect = updatedCell.modifiedByUser &&
    value && /^[A-Z0-9]$/.test(value) &&
    wordIds.every(wordId => wordValidation[wordId] === "correct");

  const showIncorrect = updatedCell.modifiedByUser &&
    value && /^[A-Z0-9]$/.test(value) &&
    wordIds.some(wordId => wordValidation[wordId] === "incorrect");

  // ✅ Marcar la palabra activa al hacer focus
  const handleFocus = () => {
    if (wordIds.length > 0) {
      dispatch(actions.setActiveWord(wordIds[0]));
    }
  };

  // ✅ Escribir y avanzar
  const handleChange = (e) => {
    const raw = e.target.value.toUpperCase().slice(-1);
    // 🔤 Solo letras o números (A-Z, 0-9)
    const input = /^[A-Z0-9]$/.test(raw) ? raw : "";

    dispatch(actions.updateCellUserInput(cell.id, input, () => {
      wordIds.forEach(wordId => {
        dispatch(actions.resetSingleWordValidation(wordId));
      });
    }));

    if (!input || !activeWordId) return;

    const activeWord = words?.find(w => w.id === activeWordId);
    if (!activeWord) return;

    const currentLink = updatedCell.crosswordCellWordLinkDtoList?.find(link => link.wordId === activeWordId);
    if (!currentLink) return;

    const nextPosition = currentLink.positionCell + 1;

    const nextCell = cells?.find(c =>
      c.crosswordCellWordLinkDtoList?.some(link =>
        link.wordId === activeWordId && link.positionCell === nextPosition
      )
    );

    if (nextCell && inputRefs?.current[nextCell.id]) {
      inputRefs.current[nextCell.id].current?.focus();
    }
  };

  // ✅ Clases CSS
  let cellClass = "crossword-cell";
  if (showCorrect) cellClass += " correct";
  else if (showIncorrect) cellClass += " incorrect";

  return (
    <Box className={cellClass}>
      <input
        type="text"
        value={value}
        onChange={handleChange}
        onFocus={handleFocus}
        className="crossword-input"
        maxLength={1}
        ref={inputRefs?.current[cell.id]}
      />
    </Box>
  );
};

export default CrosswordCell;
