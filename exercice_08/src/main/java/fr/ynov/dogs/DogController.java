package fr.ynov.dogs;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/dogs")
public class DogController {

    private final DogRepository repository;

    public DogController(DogRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Dog> getAll() {
        return repository.findAll();
    }

    @GetMapping("/{dogId}")
    public ResponseEntity<Dog> getOne(@PathVariable Long dogId) {
        return repository.findById(dogId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Dog create(@RequestBody Dog dog) {
        dog.setId(null);
        return repository.save(dog);
    }

    @PutMapping("/{dogId}")
    public ResponseEntity<Dog> update(@PathVariable Long dogId, @RequestBody Dog dog) {
        if (!repository.existsById(dogId)) {
            return ResponseEntity.notFound().build();
        }
        dog.setId(dogId);
        return ResponseEntity.ok(repository.save(dog));
    }

    @DeleteMapping("/{dogId}")
    public ResponseEntity<Void> delete(@PathVariable Long dogId) {
        if (!repository.existsById(dogId)) {
            return ResponseEntity.notFound().build();
        }
        repository.deleteById(dogId);
        return ResponseEntity.noContent().build();
    }
}
